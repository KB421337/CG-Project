#version 430

layout(local_size_x = 1, local_size_y = 1) in;
layout(local_size_x = 1, local_size_y = 1, local_size_z = 1) in;
uniform samplerCube skybox;
uniform vec4 aperture;
uniform mat4 rotation = mat4(1.0);
layout(rgba32f, binding = 0) uniform image2D img_output;

layout(std140, binding = 0) uniform MESH_IN
{
	vec3 verts[942];
}vertices;

uniform float size;

vec4 colour;
vec4 pixel;
vec4 rayDir;
vec4 rayOrg;

struct IntersectData
{
	float brightness;
	float dist;
	vec3 intersection;
	vec3 normal;
	vec4 colour;
};

IntersectData intersectRoom(vec3 rOrg, vec3 rDir)
{
	float halflength = 100;
	bool testBack = true, testDown = true, testLeft = true;
	vec3 nearest;
	float nearest_dist = 10000.0;
	vec3 normal;

	/* Front face */
	vec3 pPt = vec3(0.0, 0.0, -halflength);
	vec3 pNorm = vec3(0.0, 0.0, 1.0);
	float den = dot(pNorm, rDir);
	if (abs(den) > 0.0001f)
	{
		float t = dot(pPt - rOrg, pNorm)/den;
		if (t > 0.0001f) 
		{
			testBack = false;
			nearest = rOrg + t*rDir;
			nearest_dist = length(t*rDir);
			normal = pNorm;
		}
	}
	else testBack = false;

	/* Up face */
	pPt = vec3(0.0, halflength, 0.0);
	pNorm = vec3(0.0, -1.0, 0.0);
	den = dot(pNorm, rDir);
	if (abs(den) > 0.0001f)
	{
		float t = dot(pPt - rOrg, pNorm) / den;
		if (t > 0.0001f) 
		{
			testDown = false;
			float dist = length(t*rDir);
			if(dist < nearest_dist)
			{
				nearest = rOrg + t*rDir;
				nearest_dist = dist;
				normal = pNorm;
			}
		}
	}
	else testDown = false;

	/* Right face */
	pPt = vec3(halflength, 0.0, 0.0);
	pNorm = vec3(-1.0, 0.0, 0.0);
	den = dot(pNorm, rDir);
	if (abs(den) > 0.0001f)
	{
		float t = dot(pPt - rOrg, pNorm) / den;
		if (t > 0.0001f) 
		{
			testLeft = false;
			float dist = length(t*rDir);
			if(dist < nearest_dist)
			{
				nearest = rOrg + t*rDir;
				nearest_dist = dist;
				normal = pNorm;
			}
		}
	}
	else testLeft = false;

	/* Back face */
	if(testBack)
	{
		vec3 pPt = vec3(0.0, 0.0, halflength);
		vec3 pNorm = vec3(0.0, 0.0, -1.0);
		float den = dot(pNorm, rDir);
		if (abs(den) > 0.0001f)
		{
			float t = dot(pPt - rOrg, pNorm) / den;
			if (t > 0.0001f) 
			{
				float dist = length(t*rDir);
				if(dist < nearest_dist)
				{
					nearest = rOrg + t*rDir;
					nearest_dist = dist;
					normal = pNorm;
				}
			}
		}
	}

	/* Down face */
	if(testDown)
	{
		vec3 pPt = vec3(0.0, -halflength, 0.0);
		vec3 pNorm = vec3(0.0, 1.0, 0.0);
		float den = dot(pNorm, rDir);
		if (abs(den) > 0.0001f)
		{
			float t = dot(pPt - rOrg, pNorm) / den;
			if (t > 0.0001f) 
			{
				float dist = length(t*rDir);
				if(dist < nearest_dist)
				{
					nearest = rOrg + t*rDir;
					nearest_dist = dist;
					normal = pNorm;
				}
			}
		}
	}

	/* Left face */
	if(testLeft)
	{
		vec3 pPt = vec3(-halflength, 0.0, 0.0);
		vec3 pNorm = vec3(1.0, 0.0, 0.0);
		float den = dot(pNorm, rDir);
		if (abs(den) > 0.0001f)
		{
			float t = dot(pPt - rOrg, pNorm) / den;
			if (t > 0.0001f) 
			{
				float dist = length(t*rDir);
				if(dist < nearest_dist)
				{
					nearest = rOrg + t*rDir;
					nearest_dist = dist;
					normal = pNorm;
				}
			}
		}
	}

	return IntersectData(0.0, nearest_dist, nearest, normal, texture(skybox, nearest));
}

IntersectData intersectSphere(vec3 rayOrg, vec3 rayDir, vec3 centre, float rad, vec4 sphere_colour, float brightness)
{
	vec3 omc = rayOrg - centre;
	float a = dot(rayDir, rayDir);
	float b = 2.0f * dot(rayDir, omc);
	float c = dot(omc, omc) - rad*rad;
	float discriminant = b*b - 4.0f*a*c;

	if (discriminant < 0.0f)
	{
		return IntersectData(-1.0f, vec3(0.0), vec3(0.0), sphere_colour, brightness);
	}
	else
	{
		float numerator = -b - sqrt(discriminant);
		if (numerator > 0.0)
		{
			float t = numerator/2.0f*a;
			vec3 intersection = rayOrg + t*rayDir;
			float dist = length(t*rayDir);
			vec3 normal = normalize(intersection - centre);
			return IntersectData(dist, intersection, normal, sphere_colour, brightness);
		}

		numerator = -b + sqrt(discriminant);
		if (numerator > 0.0)
		{
			float t = numerator/2.0f*a;
			vec3 intersection = rayOrg + t*rayDir;
			float dist = length(t*rayDir);
			vec3 normal = normalize(intersection - centre);
			return IntersectData(dist, intersection, normal, sphere_colour, brightness);
		}
		else
		{
			return IntersectData(-1.0f, vec3(0.0), vec3(0.0), sphere_colour, brightness);
		}
	}
}

vec4 rayTrace(int bounces, vec3 origin, vec3 direction)
{
	IntersectData current_intersect;
	IntersectData nearest_intersect;
	vec3 current_rayOrg = origin;
	vec3 current_rayDir = direction;
	vec4 final_colour = vec4(1.0, 1.0, 1.0, 1.0);
	bool room = true;

	while(bounces>=0)
	{
		current_intersect = intersectRoom(current_rayOrg, current_rayDir);
		nearest_intersect = current_intersect;
		room = true;

		current_intersect = intersectSphere(current_rayOrg, current_rayDir, vec3(-5.0, 4.0, -30.0), 5.0, vec4(1.0, 1.0, 0.8, 1.0), 0.5f);
		if(current_intersect.dist > 0.001f && (nearest_intersect.dist > current_intersect.dist || nearest_intersect.dist <= 0.001f))
		{
			nearest_intersect = current_intersect;
			room = false;
		}

		current_intersect = intersectSphere(current_rayOrg, current_rayDir, vec3(5.0, -7.0, -20.0), 7.0, vec4(1.0, 0.8, 1.0, 1.0), 0.0);
		if(current_intersect.dist > 0.001f && (nearest_intersect.dist > current_intersect.dist || nearest_intersect.dist <= 0.001f))
		{
			nearest_intersect = current_intersect;
			room = false;
		}

		current_intersect = intersectSphere(current_rayOrg, current_rayDir, vec3(-8.0, -7.0, -20.0), 3.0, vec4(1.0, 1.0, 1.0, 1.0), 0.0);
		if(current_intersect.dist > 0.001f && (nearest_intersect.dist > current_intersect.dist || nearest_intersect.dist <= 0.001f))
		{
			nearest_intersect = current_intersect;
			room = false;
		}

		if(nearest_intersect.dist > 0.001f && room == false)
		{
				final_colour *= nearest_intersect.colour;
				current_rayOrg = nearest_intersect.intersection;
				current_rayDir = reflect(current_rayDir, nearest_intersect.normal);
		}
		else
		{
			final_colour *= nearest_intersect.colour;
			break;
		}
		bounces--;
	}
	return final_colour;
}

void main(){
	ivec2 pixel_coords = ivec2(gl_GlobalInvocationID.xy);

	float max_x = 5.0;
	float max_y = 5.0;
	ivec2 dims = imageSize(img_output);
	float x = max_x * (pixel_coords.x * 2 - dims.x) / dims.x;
	float y = max_y * (pixel_coords.y * 2 - dims.y) / dims.y;
	float z = 0.0;

	vec4 viewing_plane = vec4(x, y, z, 1.0) * rotation;
	ray_o = vec4(0.0, 0.0, 10.0, 1.0);
	ray_d = normalize(viewing_plane - rayOrg);

	colour = rayTrace(5, vec3(rayOrg.x, rayOrg.y, rayOrg.z), vec3(rayDir.x, rayDir.y, rayDir.z));
	pixel = colour;
	
	imageStore(img_output,pixel_coords,pixel);
}