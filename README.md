# Final Project!

This is it! The culmination of your procedural graphics experience this semester. For your final project, we'd like to give you the time and space to explore a topic of your choosing. You may choose any topic you please, so long as you vet the topic and scope with an instructor or TA. We've provided some suggestions below. The scope of your project should be roughly 1.5 homework assignments). To help structure your time, we're breaking down the project into 4 milestones:

## Project planning: Design Doc (due 11/4)
Before submitting your first milestone, _you must get your project idea and scope approved by Rachel, Adam or a TA._

### Design Doc

#### Introduction
I've always like the effects that volumetric rendering produces, and some of IQ and Maxime Heckel's shaders have inspired me to build on my star/nebula skybox and include a procedural aurora borealis, volumetric clouds, volumetric lighting, and a SDF landscape.

#### Goal
A visually compelling night skybox involving stars, aurora, volumetric clouds, volumetric lighting, and a SDF landscape.

#### Inspiration/reference: 
- Aurora: https://www.shadertoy.com/view/XtGGRt
- Clouds: https://www.shadertoy.com/view/XslGRr
- Landscape: https://www.shadertoy.com/view/4ttSWf, https://www.shadertoy.com/view/MdX3Rr

#### Specification:
- Procedural aurora borealis
- Volumetric clouds (maybe physically based)
- Some kind of volumetric lighting
- Stretch: IG style cool SDF landscape + volumetric shadowmap

#### Techniques:
- Procedural skybox: https://www.shadertoy.com/view/XtGGRt
- Volumetric rendering (clouds and lighting https://www.shadertoy.com/view/XslGRr, https://r3f.maximeheckel.com/solar)
- SDF landscapes (https://www.shadertoy.com/view/4ttSWf, https://www.shadertoy.com/view/MdX3Rr)

#### Design:
Stars and nebulae in the far background -> Clouds in front of the sun/moon -> A sun/moon producing volumetric lighting effects -> a SDF landscape drawn on the lower half of the scene.

#### Timeline:
- Week1: Porting in basecode from hw01
- Week2: Volumetric clouds
- Week3: Volumetric lighting
- Stretch: IG style cool SDF landscape + volumetric shadowmap

# Milestone #1

## Progress
- Ported in code from the fireball homework to use as the base scene of the project
- Changed camera controls based on the implementation from a former [WebGPU project](https://github.com/lukekwon98/WebGPU-Forward-Plus-and-Clustered-Deferred/tree/main)
- Adjusted original fireball(comet)'s size and made it move across the screen
- Added GUI elements for comet speed and comet scale

<img width="1725" height="892" alt="Screenshot 2026-11-11 at 7 32 56 PM" src="https://github.com/user-attachments/assets/7a77bb4d-2d21-43d4-9691-0467c800b1e4" />

# Milestone 2

## Progress

<img width="1728" height="912" alt="Screenshot 2026-11-23 at 12 17 46 PM" src="https://github.com/user-attachments/assets/bea69d5b-4780-4152-8c19-21b97053e135" />

<img width="1728" height="915" alt="Screenshot 2026-11-23 at 12 16 50 PM" src="https://github.com/user-attachments/assets/48cf239f-360f-445d-8da7-5b0fb68b21d9" />

<img width="1726" height="895" alt="Screenshot 2026-11-23 at 12 18 52 PM" src="https://github.com/user-attachments/assets/b8953968-02fa-4c5a-a410-b7b691d8eee7" />

- Built a post-process rendering pipeline supporting HDR
  - The skybox and comet render into a half-float render target, clouds render into their own target, and a final pass combines them onto the screen
- Added ACES filmic and Reinhard tone mapping
- Added a sun to the skybox shader with an exponential glow, controlled through spherical coordinates and color, intensity, size and glow sliders
- Generated a noise texture for fast 3D value noise
- Started the volumetric cloud pass following [Maxime Heckel's blog post](https://blog.maximeheckel.com/posts/real-time-cloudscapes-with-volumetric-raymarching/):
  - Fixed-step volumetric raymarching through a sphere SDF, using negated SDF distance as density and front to back alpha accumulation
  - FBM noise added to the density and animated over time to create a drifting cloud shape

## Final submission (due 11/30)
Time to polish! Spen this last week of your project using your generator to produce beautiful output. Add textures, tune parameters, play with colors, play with camera animation. Take the feedback from class critques and use it to take your project to the next level.

Submission:
- Push all your code / files to your repository
- Come to class ready to present your finished project
- Update your README with two sections 
  - final results with images and a live demo if possible
  - post mortem: how did your project go overall? Did you accomplish your goals? Did you have to pivot?

## Topic Suggestions

### Create a generator in Houdini

### A CLASSIC 4K DEMO
- In the spirit of the demo scene, create an animation that fits into a 4k executable that runs in real-time. Feel free to take inspiration from the many existing demos. Focus on efficiency and elegance in your implementation.
- Example: 
  - [cdak by Quite & orange](https://www.youtube.com/watch?v=RCh3Q08HMfs&list=PLA5E2FF8E143DA58C)

### A RE-IMPLEMENTATION
- Take an academic paper or other pre-existing project and implement it, or a portion of it.
- Examples:
  - [2D Wavefunction Collapse Pokémon Town](https://gurtd.github.io/566-final-project/)
  - [3D Wavefunction Collapse Dungeon Generator](https://github.com/whaoran0718/3dDungeonGeneration)
  - [Reaction Diffusion](https://github.com/charlesliwang/Reaction-Diffusion)
  - [WebGL Erosion](https://github.com/LanLou123/Webgl-Erosion)
  - [Particle Waterfall](https://github.com/chloele33/particle-waterfall)
  - [Voxelized Bread](https://github.com/ChiantiYZY/566-final)

### A FORGERY
Taking inspiration from a particular natural phenomenon or distinctive set of visuals, implement a detailed, procedural recreation of that aesthetic. This includes modeling, texturing and object placement within your scene. Does not need to be real-time. Focus on detail and visual accuracy in your implementation.
- Examples:
  - [The Shrines](https://github.com/byumjin/The-Shrines)
  - [Watercolor Shader](https://github.com/gracelgilbert/watercolor-stylization)
  - [Sunset Beach](https://github.com/HanmingZhang/homework-final)
  - [Sky Whales](https://github.com/WanruZhao/CIS566FinalProject)
  - [Snail](https://www.shadertoy.com/view/ld3Gz2)
  - [Journey](https://www.shadertoy.com/view/ldlcRf)
  - [Big Hero 6 Wormhole](https://2.bp.blogspot.com/-R-6AN2cWjwg/VTyIzIQSQfI/AAAAAAAABLA/GC0yzzz4wHw/s1600/big-hero-6-disneyscreencaps.com-10092.jpg)

### A GAME LEVEL
- Like generations of game makers before us, create a game which generates an navigable environment (eg. a roguelike dungeon, platforms) and some sort of goal or conflict (eg. enemy agents to avoid or items to collect). Aim to create an experience that will challenge players and vary noticeably in different playthroughs, whether that means procedural dungeon generation, careful resource management or an interesting AI model. Focus on designing a system that is capable of generating complex challenges and goals.
- Examples:
  - [Rhythm-based Mario Platformer](https://github.com/sgalban/platformer-gen-2D)
  - [Pokémon Ice Puzzle Generator](https://github.com/jwang5675/Ice-Puzzle-Generator)
  - [Abstract Exploratory Game](https://github.com/MauKMu/procedural-final-project)
  - [Tiny Wings](https://github.com/irovira/TinyWings)
  - Spore
  - Dwarf Fortress
  - Minecraft
  - Rogue

### AN ANIMATED ENVIRONMENT / MUSIC VISUALIZER
- Create an environment full of interactive procedural animation. The goal of this project is to create an environment that feels responsive and alive. Whether or not animations are musically-driven, sound should be an important component. Focus on user interactions, motion design and experimental interfaces.
- Examples:
  - [The Darkside](https://github.com/morganherrmann/thedarkside)
  - [Music Visualizer](https://yuruwang.github.io/MusicVisualizer/)
  - [Abstract Mesh Animation](https://github.com/mgriley/cis566_finalproj)
  - [Panoramical](https://www.youtube.com/watch?v=gBTTMNFXHTk)
  - [Bound](https://www.youtube.com/watch?v=aE37l6RvF-c)

### YOUR OWN PROPOSAL
- You are of course welcome to propose your own topic . Regardless of what you choose, you and your team must research your topic and relevant techniques and come up with a detailed plan of execution. You will meet with some subset of the procedural staff before starting implementation for approval.
