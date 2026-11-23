import {vec3, mat4} from 'gl-matrix';
import Stats from 'stats-js';
import * as DAT from 'dat.gui';
import Icosphere from './geometry/Icosphere';
import Square from './geometry/Square';
import Cube from './geometry/Cube';
import OpenGLRenderer from './rendering/gl/OpenGLRenderer';
import Camera from './Camera';
import {setGL} from './globals';
import ShaderProgram, {Shader} from './rendering/gl/ShaderProgram';

import lambertVertSource from './shaders/lambert-vert.glsl?raw';
import lambertFragSource from './shaders/lambert-frag.glsl?raw';

import skyboxVertSource from './shaders/skybox-vert.glsl?raw';
import skyboxFragSource from './shaders/skybox-frag.glsl?raw';

//offscreen render target + hdr format
import RenderTarget, {hdrColor} from './rendering/gl/RenderTarget';

import {createNoiseTexture, loadBlueNoise} from './rendering/NoiseTextures';
//full sreen pass shaders
import fullscreenVert from './shaders/fullscreen-vert.glsl?raw';
import compositeFrag from './shaders/composite-frag.glsl?raw';


// Define an object with application parameters and button callbacks
// This will be referred to by dat.GUI's functions that add GUI elements.
const controls = {
  tesselations: 5,
  'Load Scene': loadScene, // A function pointer, essentially
  'Reset Fireball': resetFireball,
  Base: [140, 153, 217],
  Variation: [77, 64, 26],
  Frequency: [204, 230, 255],
  Phase: [217, 230, 242],
  Tail: 1,
  Speed: 1,
  Length: 5,
  ColorWave: 0,
  CometSpeed: 50,
  CometSize: 135.0,

  LightElevation: 8, //degrees above horizon
  LightAzimuth: 0, //degrees around Y; 0 = -Z - camera's start direction
  LightColor: [255, 236, 210],
  LightIntensity: 20, //hdr brightness of the disc
  LightSize: 1.5, // angular radius in degrees
  LightGlow: 0.5, //halo strength

  Exposure: 1.0, //hdr multiplier before ton emapping
  Tonemap: 'ACES',
  DebugView: 'Final',
};

let controllers: DAT.GUIController[] = [];

function resetFireball() {
  controls.tesselations = 5;
  controls.Base = [140, 153, 217];
  controls.Variation = [77, 64, 26];
  controls.Frequency = [204, 230, 255];
  controls.Phase = [217, 230, 242];
  controls.Tail = 1;
  controls.Speed = 1;
  controls.Length = 5;
  controls.ColorWave = 0;
  controls.CometSpeed = 50.0,
  controls.CometSize = 135.0

  for(let controller of controllers){
    controller.updateDisplay();
  }
}

let icosphere: Icosphere;
let skybox: Icosphere;
let square: Square;
let prevTesselations: number = 5;
let cube: Cube;

const cometFront = vec3.normalize(vec3.create(), vec3.fromValues(1, -0.15, 0));
const cometStart = vec3.fromValues(-250, 175, -300);
let cometPos = vec3.clone(cometStart);

//Dropdown label->int the shader switches on since GLSL has no strings
const TONEMAPS: Record<string, number> = {'None': 0, 'ACES': 2, 'Reinhard': 3};
const DEBUG_VIEWS: Record<string, number> = {'Final': 0, 'Noise texture': 2, 'Noise 3D': 3, 'Blue noise': 4};

//Elevation/azimuth sliders to unit direction vector (spherical to cartesian)
function lightDirection(): vec3{
  const el = controls.LightElevation * Math.PI / 180;
  const az = controls.LightAzimuth * Math.PI / 180;
  return vec3.fromValues(Math.cos(el) * Math.sin(az), Math.sin(el), -Math.cos(el) * Math.cos(az));
}

function loadScene() {
  icosphere = new Icosphere(vec3.fromValues(0, 0, 0), 1, controls.tesselations);
  icosphere.create();
  skybox = new Icosphere(vec3.fromValues(0,0,0), 5000, 5);
  skybox.create();
  // square = new Square(vec3.fromValues(0, 0, 0));
  // square.create();
  // cube = new Cube(vec3.fromValues(0,0,0));
  // cube.create();
}

function main() {
  // Initial display for framerate
  const stats = Stats();
  stats.setMode(0);
  stats.domElement.style.position = 'absolute';
  stats.domElement.style.left = '0px';
  stats.domElement.style.top = '0px';
  document.body.appendChild(stats.domElement);

  // Add controls to the gui
  const gui = new DAT.GUI();

  //Lightsource
  const lightFolder = gui.addFolder('Light');
  lightFolder.add(controls, 'LightElevation', -10, 90).step(0.1);
  lightFolder.add(controls, 'LightAzimuth', -180, 180).step(0.1);
  lightFolder.addColor(controls, 'LightColor');
  lightFolder.add(controls, 'LightIntensity', 0, 100);
  lightFolder.add(controls, 'LightSize', 0.1, 10);
  lightFolder.add(controls, 'LightGlow', 0, 5);

  //Post processing and debug
  const renderFolder = gui.addFolder('Render');
  renderFolder.add(controls, 'Exposure', 0, 5);
  renderFolder.add(controls, 'Tonemap', Object.keys(TONEMAPS)); //dropdown
  renderFolder.add(controls, 'DebugView', Object.keys(DEBUG_VIEWS));

  const cometFolder = gui.addFolder('Comet');
  controllers.push(cometFolder.add(controls, 'tesselations', 0, 8).step(1));
  controllers.push(cometFolder.addColor(controls, 'Base'));
  controllers.push(cometFolder.addColor(controls, 'Variation'));
  controllers.push(cometFolder.addColor(controls, 'Frequency'));
  controllers.push(cometFolder.addColor(controls, 'Phase'));
  controllers.push(cometFolder.add(controls, 'Length', -20, 20).step(0.1));
  controllers.push(cometFolder.add(controls, 'ColorWave', 0, 0.2).step(0.01));
  controllers.push(cometFolder.add(controls, 'CometSpeed', 0, 500).step(0.05));
  controllers.push(cometFolder.add(controls, 'CometSize', 0.01, 1000).step(0.01));
  cometFolder.add(controls, 'Reset Fireball');

  // get canvas and webgl context
  const canvas = <HTMLCanvasElement> document.getElementById('canvas');
  const gl = <WebGL2RenderingContext> canvas.getContext('webgl2');
  if (!gl) {
    alert('WebGL 2 not supported!');
  }
  // `setGL` is a function imported above which sets the value of `gl` in the `globals.ts` module.
  // Later, we can import `gl` from `globals.ts` to access it
  setGL(gl);

  //needed to write into float textures in WebGL2
  if(!gl.getExtension('EXT_color_buffer_float')){
    alert('EXT_color_buffer_float not supported');
  }

  //quad covering the screen
  const screenQuad = new Square(vec3.fromValues(0,0,0)); //center is 0,0,0. has corners at -1 1, same as screen in clip space
  screenQuad.create();

  //offscreen framebuffer of HDR type - for skybox and comet, need depth for comet
  const sceneTarget = new RenderTarget([hdrColor()], true);

  //computed and loaded noise textures. built/loaded once, sampled every frame
  const noiseTex = createNoiseTexture();
  const blueNoise = loadBlueNoise('blue-noise.png');

  // Initial call to load scene
  loadScene();

  const camera = new Camera(vec3.fromValues(0, 0, 1), vec3.fromValues(0, 0, 0));

  const renderer = new OpenGLRenderer(canvas);
  renderer.setClearColor(0.0, 0.0, 0.0, 1);
  gl.enable(gl.DEPTH_TEST);

  const lambert = new ShaderProgram([
    new Shader(gl.VERTEX_SHADER, lambertVertSource),
    new Shader(gl.FRAGMENT_SHADER, lambertFragSource),
  ]);

  const skyShader = new ShaderProgram([
    new Shader(gl.VERTEX_SHADER, skyboxVertSource),
    new Shader(gl.FRAGMENT_SHADER, skyboxFragSource),
  ]);

  //combine pass
  const composite = new ShaderProgram([
    new Shader(gl.VERTEX_SHADER, fullscreenVert),
    new Shader(gl.FRAGMENT_SHADER, compositeFrag),
  ]);

  let time = 0;
  let lastTime = performance.now();

  // This function will be called every frame
  function tick() {
    time++;
    camera.update();
    stats.begin();
    if(controls.tesselations != prevTesselations)
    {
      prevTesselations = controls.tesselations;
      icosphere = new Icosphere(vec3.fromValues(0, 0, 0), 1, prevTesselations);
      icosphere.create();
    }
    
    //pass 1: background + comet -> hdr scene target
    sceneTarget.bind();
    gl.enable(gl.DEPTH_TEST)
    renderer.clear();

    const lc = controls.LightColor;
    skyShader.setTime(time);
    skyShader.setVec3('u_LightDir', lightDirection());
    skyShader.setVec3('u_LightColor', vec3.fromValues(lc[0]/255, lc[1]/255, lc[2]/255));
    skyShader.setFloat('u_LightIntensity', controls.LightIntensity);
    skyShader.setFloat('u_LightSize', controls.LightSize * Math.PI / 180); //deg to rad
    skyShader.setFloat('u_LightGlow', controls.LightGlow);

    renderer.renderSkybox(
      camera,
      skyShader,
      skybox
    );


    // Fireball
    const now = performance.now();
    const dt = Math.min((now - lastTime) / 1000, 0.1);
    lastTime = now;

    vec3.scaleAndAdd(cometPos, cometPos, cometFront, controls.CometSpeed * dt);
    if (vec3.distance(cometPos, cometStart) > 1000){
      vec3.copy(cometPos, cometStart);
    }

    const model = mat4.create();
    mat4.translate(model, model, cometPos);
    mat4.scale(model, model, [controls.CometSize, controls.CometSize, controls.CometSize]);

    lambert.setTime(time);
    lambert.setTailDir(vec3.negate(vec3.create(), cometFront));

    renderer.render(camera, lambert, model, 
      vec3.fromValues(controls.Base[0], controls.Base[1], controls.Base[2]),
      vec3.fromValues(controls.Variation[0], controls.Variation[1], controls.Variation[2]),
      vec3.fromValues(controls.Frequency[0], controls.Frequency[1], controls.Frequency[2]),
      vec3.fromValues(controls.Phase[0], controls.Phase[1], controls.Phase[2]),
      controls.Tail,
      controls.Speed,
      controls.Length,
      controls.ColorWave,
      [
      icosphere,
      //skybox,
      //square
      //cube,
    ]);

    //pass2 composite -> canvas
    const viewProj = mat4.multiply(mat4.create(), camera.projectionMatrix, camera.viewMatrix);

    RenderTarget.bindScreen(canvas.width, canvas.height); //back to the canvas
    gl.disable(gl.DEPTH_TEST); //no depth test needed for full screen quad

    //one texture unit per texture so the shader can read all three
    composite.setTexture('u_Scene', 0, sceneTarget.texture());
    composite.setTexture('u_Noise', 1, noiseTex);
    composite.setTexture('u_BlueNoise', 2, blueNoise);

    composite.setMat4('u_InvViewProj', mat4.invert(mat4.create(), viewProj));
    composite.setFloat('u_Exposure', controls.Exposure);
    composite.setInt('u_Tonemap', TONEMAPS[controls.Tonemap]);
    composite.setInt('u_DebugView', DEBUG_VIEWS[controls.DebugView]);
    composite.setFloat('u_Time', time);
    composite.setVec2('u_Resolution', canvas.width, canvas.height);
    composite.draw(screenQuad);

    stats.end();

    // Tell the browser to call `tick` again whenever it renders a new frame
    requestAnimationFrame(tick);
  }

  function onResize(){
    renderer.setSize(window.innerWidth, window.innerHeight);
    camera.setAspectRatio(window.innerWidth/window.innerHeight);
    camera.updateProjectionMatrix();
    sceneTarget.resize(canvas.width,canvas.height);
  }
  window.addEventListener('resize', onResize);
  onResize();

  // Start the render loop
  tick();
}

main();
