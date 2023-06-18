# Metropolis Light Transport
IS F311, Computer Graphics Project

## Team members
- `K Anish Kumar`
- `Kaustubh Bhanj`
- `Nishith Kumar`
- `Kevin K Biju`
- `Arjav Garg`
- `Shreyas Gupta`

# Aim
- The project aims to understand the underlying theory of MLT Algorithm - The Metropolis-Hastings Algorithm, Markov Chain Monte Carlo (MCMC) Methods, Monte Carlo Integration, the rendering equation and the concept of recursive ray tracing.
- The goal of photorealistic rendering is to create an image of a 3D scene that is indistinguishable from a photograph of the same scene - an accurate simulation of the physics of light and its interaction with matter is attempted.

# Ray Tracing
- In simple terms, ray tracing realistically simulates lighting of a scene and its objects.
- This is accountable for all the optical effects like reflection, refraction, shadows, scattering and so on. The algorithms are based on following the path of a ray of light through a scene as it interacts and bounces off objects in a scene.
- All of ray tracing algorithms simulate atleast the Camera, and Ray-Object intersections.
- The Camera: determines how and from where a scene is being viewed , including how an image of a scene is captured on the sensor. Most of the rendering systems generate rays starting at camera and traced throughout the scene.
- Ray-Object intersections: Most Ray tracers have a way to test intersections of a ray with multiple objects , typically returning the closest intersection along the ray.

# Path Tracing
## Rendering equation
- In computer graphics, the rendering equation is an integral equation in which the equilibrium radiance leaving a point is given as the sum of emitted plus reflected radiance under a geometric optics approximation.
- It is based on the law of conservation of energy.
- The various realistic rendering techniques in computer graphics attempt to solve this equation.

## Monte Carlo methods
- These are a set of computational algorithms relying on random sampling to get numerical results.
- The Monte Carlo methods find their use primarily in problems inolving probabilistic interpretation. The underlying concept is to use randomness to solve problems that might be deterministic in principle.
- Monte Carlo methods are mainly used in three problem classes: optimization, numerical integration, and generating draws from a probability distribution.

## Path Tracing
- It was the first general-purpose unbiased Monte Carlo light transport algorithm used in graphics.
- Introduced as an algorithm to find a numerical solution to the integral of the rendering equation.
- Incrementally generates paths of scattering events starting at the camera and ending at light sources in the scene. Repeated sampling of any given pixel eventually causes the average of the samples to converge on the correct solution of the rendering equation.

# Metropolis Light Transport
## Markov Chain
- A stochastic model comprising of objects usually defined as a family of random variables, describing a sequence of possible events in which probability of next event depends solely on that of the current state.
- To avoid any process termination, it is assumed that all possible states and the nodes in transition matrix are included in definition of the process itself.
- Markovian processes are the basis for simulation methods called Markov Chain Monte Carlo

## Markov Chain Monte Carlo - MCMC
- These methods cover a class of algorithms for sampling from a probability distribution.
- A markov chain (which has the desired distribution as its equilibrium distribution) is constructed and states from the chain are recorded to get a sample of the desired distribution.
- The model can be improved by increasing the number of steps involved.

## Metropolis-Hastings algorithm
- This is an MCMC method to get a sequence of random samples from a desired probability distribution, particularily useful when direct sampling is difficult.
- The algorithm finds its uses in approximating distitbutions and evaluating statistical integrals.
- The algorithm can draw samples from a distribution with probability density P(x) , given a function f(x) which is proportional to our density P. It iteratively generates a sequence of samples such that with production of more samples, the distribution matches closer to the actual desired one.
- At each iteration, a candidate is picked for the next random value based on current state. This is either accepted or rejected with some probability threshold, with the current value being passed on for later iterations in latter case.

## Metropolis Light Transport
- MLT generates a sequence of light-carrying paths through the scene, where each path is found by mutating the previous path in some manner.
- The path mutations are done in a way that ensures that the overall distribution of sampled paths is proportional to the contribution the paths make to the image being generated.
- MLT provides an important advantage over methods based on independent sample generation since it can explore the path space locally.
- It can easily render challenging scenes like a dark room with light only entering from a partially open door.

# Tech used
- C++ 
- OpenGL

  
