
// Structs
struct Boid {
    pos: vec3f,
    vel: vec3f,
};
struct Uniforms {
    time: f32,
    deltaTime: f32,
    width: f32,
    height: f32,
    depth: f32,
    numBoids: f32,
    maxSpeed: f32,
    maxForce: f32,
    separationRadius: f32,
    alignmentRadius: f32,
    cohesionRadius: f32,
    separationWeight: f32,
    alignmentWeight: f32,
    cohesionWeight: f32,
    mouseX: f32,
    mouseY: f32,
    mouseActive: f32,
    mouseMode: f32,
    cameraPosX: f32,
    cameraPosY: f32,
    cameraPosZ: f32,
    cameraTargetX: f32,
    cameraTargetY: f32,
    cameraTargetZ: f32,
};
struct FragmentInput {
    @location(0) vColor: vec3f,
    @location(1) vNormal: vec3f,
    @location(2) vWorldPos: vec3f,
};
struct FragmentOutput {
    @location(0) color: vec4f,
};

// Bindings
@group(0) @binding(0) var<storage, read> boids: array<Boid>;
@group(0) @binding(1) var<uniform> uniforms: Uniforms;

// Main Function
@fragment
fn fs(input: FragmentInput) -> FragmentOutput {
    
    // Lighting
    let sunDir = normalize(vec3f(0.3, 1.0, 0.5));
    let normal = normalize(input.vNormal);
    let ambient = 0.4;
    let diffuse = max(dot(normal, sunDir), 0.0);

    // Combine
    let light = ambient + diffuse;
    let color = input.vColor * light;
    
    var output: FragmentOutput;
    output.color = vec4f(color, 1.0);
    return output;

}