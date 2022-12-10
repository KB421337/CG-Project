#version 430

layout(local_size_x = 1, local_size_y = 1) in;
layout(local_size_x = 1, local_size_y = 1, local_size_z = 1) in;
uniform samplerCube skybox;
uniform mat4 rotate_matrix;
uniform float seed;
layout(rgba32f, binding = 0) uniform image2D img_output;

layout(std140, binding = 0) uniform MESH_IN
{
	vec3 verts[1000];
} vertices;

uniform float size;

vec4 pixel;
vec4 directional_light = vec4(normalize(vec3(-1.0, -1.0, 0.0)).xyz, 1.0f);

struct Ray
{
    vec3 origin;
    vec3 direction;
    vec3 energy;
};

struct RayHit
{
    vec3 position;
    float dist;
    vec3 normal;
    vec3 albedo;
    vec3 specular;
    float smoothness;
    vec3 emission;
	bool skybox;
};

RayHit CreateRayHit()
{
    RayHit hit;
    hit.position = vec3(0.0f,0.0f,0.0f);
    hit.dist = -1;
    hit.normal = vec3(0.0f,0.0f,0.0f);
    hit.albedo = vec3(0.0f,0.0f,0.0f);
    hit.specular = vec3(0.0f,0.0f,0.0f);
    hit.smoothness = 0.0f;
    hit.emission = vec3(0,0,0);
	hit.skybox = false;
    return hit;
}

struct Sphere
{
    vec3 position;
    float radius;
    vec3 albedo;
    vec3 specular;
	float smoothness;
	vec3 emission;
};

float internal_seed = seed;
/// Random float generator between [ 0.0, 1.0 )
float rand()
{
    float result = fract(sin(internal_seed/100.0f*dot(pixel.xy ,vec2(12.9898f,78.233f))) * 43758.5453f);
	internal_seed += 1.0f;
	return result;
}

/// Utility function for dotting two vectors and clamping them between 0 and 1
float sdot(vec3 x, vec3 y, float f)
{
    return clamp(dot(x,y)*f, 0.0, 1.0);
}
 
/// Utility function for averaging the 3 color channels
float energy(vec3 colour)
{
    return dot(colour,vec3(1.0f/3.0f));
}

/// Converts a smoothness value to alpha for the scattering distribution
float SmoothnessToPhongAlpha(float s)
{
    return pow(1000.0f,s*s);
}

/// Find the tangent space given a normal
mat3 GetTangentSpace(vec3 normal)
{
    vec3 helper = vec3(1,0,0);
    if(abs(normal.x)>0.99f)
        helper = vec3(0,0,1);
    
    vec3 tangent = normalize(cross(normal,helper));
    vec3 binormal = normalize(cross(normal,tangent));
 
    return mat3(tangent,binormal,normal);
}

/// Samples the hemisphere around the given normal and biases it based on the given alpha
vec3 SampleHemisphere(vec3 normal, float alpha)
{
    float cosTheta = pow(rand(), 1.0f / (alpha + 1.0f));
    float sinTheta = sqrt(max(0.0f,1.0f - cosTheta*cosTheta));
    float phi = 2 * 3.141592f * rand();
    vec3 tangentSpaceDir = vec3(cos(phi)*sinTheta,sin(phi)*sinTheta,cosTheta);
 
    return GetTangentSpace(normal)*tangentSpaceDir;
}

bool intersectTriangle_MT97(Ray ray, vec3 vert0, vec3 vert1, vec3 vert2, inout float t, inout float u, inout float v)
{
    // find vectors for two edges sharing vert0
    vec3 edge1 = vert1 - vert0;
    vec3 edge2 = vert2 - vert0;
    // begin calculating determinant - also used to calculate U parameter
    vec3 pvec = cross(ray.direction, edge2);
    // if determinant is near zero, ray lies in plane of triangle
    float det = dot(edge1, pvec);
    // use backface culling
    if (det < 0.001f)
        return false;
    float inv_det = 1.0f / det;
    // calculate distance from vert0 to ray origin
    vec3 tvec = ray.origin - vert0;
    // calculate U parameter and test bounds
    u = dot(tvec, pvec) * inv_det;
    if (u < 0.0 || u > 1.0f)
        return false;
    // prepare to test V parameter
    vec3 qvec = cross(tvec, edge1);
    // calculate V parameter and test bounds
    v = dot(ray.direction, qvec) * inv_det;
    if (v < 0.0 || u + v > 1.0f)
        return false;
    // calculate t, ray intersects triangle
    t = dot(edge2, qvec) * inv_det;
    return true;
}

void intersectRoom(Ray ray, inout RayHit bestHit)
{
	float halflength = 10000;
	bool testBack=true, testLeft=true, testBottom=true;
	vec3 nearest;
	float nearest_dist = 10000000.0;
	vec3 normal;

	//front face
	vec3 p_point = vec3(0.0, 0.0, -halflength);
	vec3 p_normal = vec3(0.0, 0.0, 1.0);
	float denom = dot(p_normal, ray.direction);
	if (abs(denom) > 0.0001f) // your favorite epsilon
	{
		float t = dot(p_point - ray.origin, p_normal) / denom;
		if (t > 0.0001f) 
		{
			testBottom = false;
			nearest = ray.origin+t*ray.direction;
			nearest_dist = t;
			normal = p_normal;
		}
	}
	else testBack = false;

	//right face
	p_point = vec3(halflength, 0.0, 0.0);
	p_normal = vec3(-1.0, 0.0, 0.0);
	denom = dot(p_normal, ray.direction);
	if (abs(denom) > 0.0001f) // your favorite epsilon
	{
		float t = dot(p_point - ray.origin, p_normal) / denom;
		if (t > 0.0001f) 
		{
			testLeft = false;
			float dist = t;
			if(dist < nearest_dist)
			{
				nearest = ray.origin+t*ray.direction;
				nearest_dist = dist;
				normal = p_normal;
			}
		}
	}
	else testLeft = false;

	//top face
	p_point = vec3(0.0, halflength, 0.0);
	p_normal = vec3(0.0, -1.0, 0.0);
	denom = dot(p_normal, ray.direction);
	if (abs(denom) > 0.0001f) // your favorite epsilon
	{
		float t = dot(p_point - ray.origin, p_normal) / denom;
		if (t > 0.0001f) 
		{
			testBottom = false;
			float dist = t;
			if(dist < nearest_dist)
			{
				nearest = ray.origin+t*ray.direction;
				nearest_dist = dist;
				normal = p_normal;
			}
		}
	}
	else testBottom = false;

	//back face
	if(testBack)
	{
		vec3 p_point = vec3(0.0, 0.0, halflength);
		vec3 p_normal = vec3(0.0, 0.0, -1.0);
		float denom = dot(p_normal, ray.direction);
		if (abs(denom) > 0.0001f) // your favorite epsilon
		{
			float t = dot(p_point - ray.origin, p_normal) / denom;
			if (t > 0.0001f) 
			{
				float dist = t;
				if(dist < nearest_dist)
				{
					nearest = ray.origin+t*ray.direction;
					nearest_dist = dist;
					normal = p_normal;
				}
			}
		}
	}

	//left face
	if(testLeft)
	{
		vec3 p_point = vec3(-halflength, 0.0, 0.0);
		vec3 p_normal = vec3(1.0, 0.0, 0.0);
		float denom = dot(p_normal, ray.direction);
		if (abs(denom) > 0.0001f) // your favorite epsilon
		{
			float t = dot(p_point - ray.origin, p_normal) / denom;
			if (t > 0.0001f) 
			{
				float dist = t;
				if(dist < nearest_dist)
				{
					nearest = ray.origin+t*ray.direction;
					nearest_dist = dist;
					normal = p_normal;
				}
			}
		}
	}

	//bottom face
	if(testBottom)
	{
		vec3 p_point = vec3(0.0, -halflength, 0.0);
		vec3 p_normal = vec3(0.0, 1.0, 0.0);
		float denom = dot(p_normal, ray.direction);
		if (abs(denom) > 0.0001f) // your favorite epsilon
		{
			float t = dot(p_point - ray.origin, p_normal) / denom;
			if (t > 0.0001f) 
			{
				float dist = t;
				if(dist < nearest_dist)
				{
					nearest = ray.origin+t*ray.direction;
					nearest_dist = dist;
					normal = p_normal;
				}
			}
		}
	}
	if(nearest_dist < bestHit.dist || bestHit.dist == -1)
	{
		bestHit.dist = nearest_dist;
		bestHit.position = ray.origin + nearest_dist * ray.direction;
		bestHit.normal = normal;
		bestHit.albedo = vec3(texture(skybox, normalize(nearest)).xyz);
		bestHit.specular = vec3(0.0);
		bestHit.emission = vec3(0.25);
		bestHit.smoothness = 0.0;
		bestHit.skybox = true;
	}
//	return vec3(1.0, 0.0, 0.0);
}

/// Legacy function that returns the color of the pixel in the background intersected by a ray
///
/// @param r_origin The origin of the ray
/// @param r_direcion The direction of the ray
vec3 drawBackground(vec3 r_origin, vec3 r_direction)
{
	float halflength = 10000;
	bool testBack=true, testLeft=true, testBottom=true;
	vec3 nearest;
	float nearest_dist = 10000000.0;

	//front face
	vec3 p_point = vec3(0.0, 0.0, -halflength);
	vec3 p_normal = vec3(0.0, 0.0, 1.0);
	float denom = dot(p_normal, r_direction);
	if (abs(denom) > 0.0001f) // your favorite epsilon
	{
		float t = dot(p_point - r_origin, p_normal) / denom;
		if (t > 0.0001f) 
		{
			testBottom = false;
			nearest = r_origin+t*r_direction;
			nearest_dist = length(t*r_direction);
		}
	}
	else testBottom = false;

	//right face
	p_point = vec3(halflength, 0.0, 0.0);
	p_normal = vec3(-1.0, 0.0, 0.0);
	denom = dot(p_normal, r_direction);
	if (abs(denom) > 0.0001f) // your favorite epsilon
	{
		float t = dot(p_point - r_origin, p_normal) / denom;
		if (t > 0.0001f) 
		{
			testLeft = false;
			float dist = length(t*r_direction);
			if(dist < nearest_dist)
			{
				nearest = r_origin+t*r_direction;
				nearest_dist = dist;
			}
		}
	}
	else testLeft = false;

	//top face
	p_point = vec3(0.0, halflength, 0.0);
	p_normal = vec3(0.0, -1.0, 0.0);
	denom = dot(p_normal, r_direction);
	if (abs(denom) > 0.0001f) // your favorite epsilon
	{
		float t = dot(p_point - r_origin, p_normal) / denom;
		if (t > 0.0001f) 
		{
			testBottom = false;
			float dist = length(t*r_direction);
			if(dist < nearest_dist)
			{
				nearest = r_origin+t*r_direction;
				nearest_dist = dist;
			}
		}
	}
	else testBottom = false;

	//back face
	if(testBack)
	{
		vec3 p_point = vec3(0.0, 0.0, halflength);
		vec3 p_normal = vec3(0.0, 0.0, -1.0);
		float denom = dot(p_normal, r_direction);
		if (abs(denom) > 0.0001f) // your favorite epsilon
		{
			float t = dot(p_point - r_origin, p_normal) / denom;
			if (t > 0.0001f) 
			{
				float dist = length(t*r_direction);
				if(dist < nearest_dist)
				{
					nearest = r_origin+t*r_direction;
					nearest_dist = dist;
				}
			}
		}
	}

	//left face
	if(testLeft)
	{
		vec3 p_point = vec3(-halflength, 0.0, 0.0);
		vec3 p_normal = vec3(1.0, 0.0, 0.0);
		float denom = dot(p_normal, r_direction);
		if (abs(denom) > 0.0001f) // your favorite epsilon
		{
			float t = dot(p_point - r_origin, p_normal) / denom;
			if (t > 0.0001f) 
			{
				float dist = length(t*r_direction);
				if(dist < nearest_dist)
				{
					nearest = r_origin+t*r_direction;
					nearest_dist = dist;
				}
			}
		}
	}

	//bottom face
	if(testBottom)
	{
		vec3 p_point = vec3(0.0, -halflength, 0.0);
		vec3 p_normal = vec3(0.0, 1.0, 0.0);
		float denom = dot(p_normal, r_direction);
		if (abs(denom) > 0.0001f) // your favorite epsilon
		{
			float t = dot(p_point - r_origin, p_normal) / denom;
			if (t > 0.0001f) 
			{
				float dist = length(t*r_direction);
				if(dist < nearest_dist)
				{
					nearest = r_origin+t*r_direction;
					nearest_dist = dist;
				}
			}
		}
	}
	return vec3(texture(skybox, normalize(nearest)).xyz);
//	return vec3(1.0, 0.0, 0.0);
}

/// Tests the intersection of a ray and the ground plane
///
/// @param ray The ray to test intersection of the ground against
/// @param bestHit The previous best hit is to be provided so that we can test if the ground will be visible to that ray. If it is, the bestHit is modified
void intersectGroundPlane(Ray ray, inout RayHit bestHit)
{
	float t = (- ray.origin.y - 17.0f ) / ray.direction.y;
	if (t > 0.1f && (t < bestHit.dist || bestHit.dist == -1))
	{
		bestHit.dist = t;
		bestHit.position = ray.origin + t * ray.direction;
		bestHit.normal = vec3(0.0, 1.0, 0.0);
		bestHit.albedo = vec3(1.0);
		bestHit.specular = vec3(1.0);
		bestHit.emission = vec3(0.0, 0.0, 0.0);
		bestHit.smoothness = 0.6;
		bestHit.skybox = false;
	}
}

/// Tests the intersection of a ray and a sphere
///
/// @param ray The ray to test intersection of the ground against
/// @param bestHit The previous best hit is to be provided so that we can test if the ground will be visible to that ray. If it is, the bestHit is modified
/// @param sphere The sphere object containing all its properties
void intersectSphere(Ray ray, inout RayHit bestHit, Sphere sphere)
{
	vec3 d = ray.origin - sphere.position;
	float p1 = -dot(ray.direction, d);
    float p2sqr = p1 * p1 - dot(d, d) + sphere.radius * sphere.radius;
    if (p2sqr < 0)
        return;
    float p2 = sqrt(p2sqr);
    float t = p1 - p2 > 0 ? p1 - p2 : p1 + p2;
    if (t > 0.1f && (t < bestHit.dist || bestHit.dist == -1))
    {
        bestHit.dist = t;
        bestHit.position = ray.origin + t * ray.direction;
        bestHit.normal = normalize(bestHit.position - sphere.position);
        bestHit.albedo = sphere.albedo;
        bestHit.specular = sphere.specular;
		bestHit.emission = sphere.emission;
		bestHit.smoothness = sphere.smoothness;
		bestHit.skybox = false;
    }
}

/// Driver tracing function that loops through all the objects in the scene and tests interection
///
/// @param ray The ray to test intersection of all the objects against
/// @returns The hit properties of the closest object
RayHit Trace(Ray ray)
{
	RayHit bestHit = CreateRayHit();

	intersectRoom(ray, bestHit);
	intersectGroundPlane(ray, bestHit);

	intersectSphere(ray, bestHit, Sphere(vec3(-17.0f, -9.0, -62.0f), 7.0, vec3(0.0), vec3(1.0, 0.78f, 0.34f), 1.0, vec3(1.0)));
	intersectSphere(ray, bestHit, Sphere(vec3(-15.0f, -12.6, -30.0f), 4.0, vec3(0.0), vec3(1.0, 1.0f, 1.0f), 1.2, vec3(0.0)));
	intersectSphere(ray, bestHit, Sphere(vec3(-5.0f, -13.0, -45.0f), 3.0, vec3(1.0, 1.0, 1.0), vec3(1.0), 0.8, vec3(0.0, 10.0, 10.0)));
	intersectSphere(ray, bestHit, Sphere(vec3(-3.0f, -9.6, -75.0f), 7.0, vec3(0.0, 0.0, 0.0), vec3(1.0, 0.35, 0.45), 0.1, vec3(0.0)));
	intersectSphere(ray, bestHit, Sphere(vec3(1.0f, -14.6, -62.0f), 2.0, vec3(0.0, 0.0, 0.0), vec3(1.0, 1.0, 1.0), 0.0, vec3(0.0)));
	intersectSphere(ray, bestHit, Sphere(vec3(8.0f, -11.0, -50.0f), 5.0, vec3(0.0, 0.0, 0.0), vec3(1.0, 1.0, 0.0), 0.8, vec3(1.0)));
	
	vec3 v0 = vec3(-10, -17, -55);
	vec3 v1 = vec3(0, -17, -55);
	vec3 v2 = vec3(-5, -6, -55);
	float t, u, v;
	if (intersectTriangle_MT97(ray, v0, v1, v2, t, u, v))
	{
		if (t > 0 && t < bestHit.dist)
		{
			bestHit.dist = t;
			bestHit.position = ray.origin + t * ray.direction;
			bestHit.normal = normalize(cross(v1 - v0, v2 - v0));
			bestHit.albedo = vec3(0.0f);
			bestHit.specular = 0.65f * vec3(1, 0.4f, 0.2f);
			bestHit.smoothness = 0.9f;
			bestHit.emission = vec3(0.0f);
		}
	}
 
    return bestHit;
}

/// Driver coloring function that colors pixels based on hit properties, and then modifies the ray to denote the new reflection direction
///
/// @param ray The ray to modify after coloring
/// @returns The emissivity of the hit object
vec3 Shade(inout Ray ray, RayHit hit)
{
	if(hit.dist > 0.01f)
	{
		if(hit.skybox)
		{
			ray.energy *= hit.albedo;
			return hit.emission;
		}

		hit.albedo = min(1.0f - hit.specular, hit.albedo);
		float specChance = energy(hit.specular);
		float diffChance = energy(hit.albedo);
		float sum = specChance + diffChance;
		specChance /= sum;
		diffChance /= sum;

		float roulette = rand();
		if (roulette < specChance)
		{
			//Diffuse reflection
			ray.origin = hit.position + hit.normal * 0.001f;
			float alpha = SmoothnessToPhongAlpha(hit.smoothness);
			ray.direction = SampleHemisphere(reflect(ray.direction, hit.normal), alpha);
			float f = (alpha+2)/(alpha+1);
			ray.energy *= (1.0f / specChance) * hit.specular * sdot(hit.normal, ray.direction, f);
		}
		else
		{
			//Specular reflection
			ray.origin = hit.position + hit.normal * 0.001f;
			ray.direction = SampleHemisphere(hit.normal, 1.0f);
			ray.energy *= (1.0f / diffChance) * hit.albedo;
		}
		return hit.emission;
 
	}
	else
	{
		ray.energy = vec3(0.0f);
		return vec3(0.0, 0.0, 0.0);
	}
}

/// Main driver function that loop through all pixels and fills them with a color
void main()
{
	ivec2 pixel_coords = ivec2(gl_GlobalInvocationID.xy);

	float max_x = 5.0;
	float max_y = 5.0;
	ivec2 dims = imageSize(img_output);
	float x = float(pixel_coords.x * 2 - dims.x) / dims.x;
	float y = float(pixel_coords.y * 2 - dims.y) / dims.y;
	pixel = vec4(pixel_coords.x, pixel_coords.y, 0.0, 1.0);
	Ray ray;
	ray.origin = vec3(0.0, 0.0, 10.0);
	vec4 initial = vec4(normalize(vec3(x*max_x,y*max_y,0.0) - ray.origin).xyzz);
	ray.direction = vec3((rotate_matrix * initial).xyz);
	ray.energy = vec3(1.0f);

	vec3 result = vec3(0.0, 0.0, 0.0);
	for(int i = 0; i <= 4; i++){
        RayHit hit = Trace(ray);
        result += ray.energy * Shade(ray,hit);
    
        if(ray.energy.x==0.0 && ray.energy.y==0.0 && ray.energy.y==0.0) break;
    }

	pixel = vec4(result, 1.0);
	
	imageStore(img_output,pixel_coords,pixel);
}