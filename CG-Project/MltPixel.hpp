#pragma once

#include "glm/glm.hpp"
#include <atomic>
#include <random>
#include <set>

#define NUM_HITS 10
#define SAMPLES 30
#define MUTATIONS 0

#define ivec2 glm::ivec2
#define vec2 glm::highp_f32vec2
#define vec3 glm::highp_f32vec3
#define vec4 glm::highp_f32vec4
#define mat3 glm::highp_f32mat3
#define mat4 glm::highp_f32mat4

struct Ray
{
	vec3 dir;
	vec3 nrg;
	vec3 org;
};

struct RayHit
{
	double dist;
	double smoothness;
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
	double rad;
	vec3 albedo;
	vec3 specular;
	double smoothness;
	vec3 emission;

	Sphere(vec3 pos, float rad, vec3 albedo, vec3 specular, double smoothness, vec3 emission) : pos(pos), rad(rad), albedo(albedo), specular(specular), smoothness(smoothness), emission(emission)
	{}
};

struct mvec4 {
	vec4 color;

	mvec4(vec4 color) : color(color) {}
};

RayHit Trace(Ray ray);
vec3 Shade(Ray& ray, RayHit hit, std::mt19937& e2, std::uniform_real_distribution<double>& dist);
void drawPixel(int x, int y, int imgWidth, int imgHeight, vec4* frameBuffer, std::atomic<int>& done, std::set<mvec4>& colors);