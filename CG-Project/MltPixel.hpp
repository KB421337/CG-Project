#pragma once

#include <atomic>
#include <list>
#include <random>
#include <set>

#include "glm/glm.hpp"

#define NUM_HITS 10
#define SAMPLES 1
#define MUTATIONS 100

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
	vec3 rslt;
	int nextA;
	int nextM;
};

struct Path 
{
	PathNode nodes[NUM_HITS];
};

struct Sph
{
	vec3 pos;
	double rad;
	vec3 albedo;
	vec3 specular;
	double smoothness;
	vec3 emission;
	Sph(vec3 pos, float rad, vec3 albedo, vec3 specular, double smoothness, vec3 emission) : pos(pos), rad(rad), albedo(albedo), specular(specular), smoothness(smoothness), emission(emission)
	{}
};

struct mvec4 
{
	vec4 colour;
	mvec4(vec4 color) : colour(colour)
	{}
};

RayHit Trc(Ray ray);
vec3 Shd(Ray& ray, RayHit hit, std::mt19937& e2, std::uniform_real_distribution<double>& dist);
void drawPixel(int x, int y, int imgWid, int imgHt, vec4* frmBuff, std::atomic<int>& done);