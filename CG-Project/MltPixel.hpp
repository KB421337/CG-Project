#pragma once

#include "glm/glm.hpp"

#define NUM_HITS 5
#define SAMPLES 1
#define MUTATIONS 0

#define ivec2 glm::ivec2
#define vec2 glm::vec2
#define vec3 glm::vec3
#define vec4 glm::vec4
#define mat3 glm::mat3

struct Ray
{
	vec3 dir;
	vec3 nrg;
	vec3 org;
};

struct RayHit
{
	float dist;
	float smoothness;
	bool skybox;
	vec3 albedo;
	vec3 emission;
	vec3 norm;
	vec3 pos;
	vec3 specular;
};

struct PathNode
{
	RayHit hit;
	Ray ray;
	vec3 result;
	int nextA;
	int nextM;
};

struct Path {
	PathNode nodes[NUM_HITS];
};

struct Sphere
{
	vec3 pos;
	float rad;
	vec3 albedo;
	vec3 specular;
	float smoothness;
	vec3 emission;

	Sphere(vec3 pos, float rad, vec3 albedo, vec3 specular, float smoothness, vec3 emission) : pos(pos), rad(rad), albedo(albedo), specular(specular), smoothness(smoothness), emission(emission)
	{}
};

RayHit Trace(Ray ray);
vec3 Shade(Ray& ray, RayHit hit);
void drawPixel(int x, int y, int imgWidth, int imgHeight, vec4* frameBuffer);