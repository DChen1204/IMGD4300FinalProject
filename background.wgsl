
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
struct VertexInput {
    @builtin(vertex_index) vertexIndex: u32,
};
struct VertexOutput {
    @builtin(position) position: vec4f,
    @location(0) uv: vec2f,
};

//=====================================================================================
//=====================================================================================

// Bindings
@group(0) @binding(0) var<storage, read> boids: array<Boid>;
@group(0) @binding(1) var<uniform> uniforms: Uniforms;

//=====================================================================================
//=====================================================================================

// Vertex Shader
@vertex
fn vs(input: VertexInput) -> VertexOutput {

    // Two triangles covering the whole screen
    var pos = array<vec2f, 6>(
        vec2f(-1.0, -1.0),
        vec2f(1.0, -1.0),
        vec2f(-1.0, 1.0),
        vec2f(-1.0, 1.0),
        vec2f(1.0, -1.0),
        vec2f(1.0, 1.0),
    );
    var uv = array<vec2f, 6>(
        vec2f(0.0, 1.0),
        vec2f(1.0, 1.0),
        vec2f(0.0, 0.0),
        vec2f(0.0, 0.0),
        vec2f(1.0, 1.0),
        vec2f(1.0, 0.0),
    );

    var output: VertexOutput;
    output.position = vec4f(pos[input.vertexIndex], 0.0, 1.0);
    output.uv = uv[input.vertexIndex];
    return output;

}

//=====================================================================================
//=====================================================================================

// Draw the sky 
fn getSkyColor(rd: vec3f) -> vec3f {
    let sunDir = normalize(vec3f(0.3, 1.0, 0.5));

    // Base sky gradient
    let t = rd.y * 0.5 + 0.5;
    let sky = mix(
        vec3f(0.2, 0.4, 1.0),
        vec3f(0.9, 0.8, 0.4),
        t
    );

    // Sun glow
    let sunDot = max(dot(rd, sunDir), 0.0);
    let hemisphere = vec3f(0.9, 0.1, 0.5) * max(rd.y, 0.0);

    return sky + hemisphere;
}

// Draw the ground
fn getGroundColor(hitPos: vec3f) -> vec3f {
    let baseColor = vec3f(0.3, 0.35, 0.25);

    // Draw the grid 
    let scale = 20.0;
    let gridX = step(0.9, fract(hitPos.x / scale));
    let gridZ = step(0.9, fract(hitPos.z / scale));
    let grid = max(gridX, gridZ);
    var matColor = mix(baseColor, vec3f(0.4, 0.9, 0.9), grid);

    // lighting
    let sunDir = normalize(vec3f(0.3, 1.0, 0.5));
    let diffuse = max(dot(vec3f(0.0, 1.0, 0.0), sunDir), 0.0);
    let ambient = 0.4;
    let light = ambient + diffuse;

    return matColor * light;
}

// Vertex Shader
@fragment
fn fs(input: VertexOutput) -> @location(0) vec4f {

    let uv = input.uv;

    // Camera setup
    let cameraPos = vec3f(uniforms.cameraPosX, uniforms.cameraPosY, uniforms.cameraPosZ);
    let cameraTarget = vec3f(uniforms.cameraTargetX, uniforms.cameraTargetY, uniforms.cameraTargetZ);
    
    let forward = normalize(cameraTarget - cameraPos);
    let worldUp = vec3f(0.0, 1.0, 0.0);
    let right = normalize(cross(worldUp, forward) + vec3f(0.0001, 0.0, 0.0001));
    let up = cross(forward, right);
    
    let fov = 1.5;
    let aspect = uniforms.width / uniforms.height;
    let rd = normalize(
        forward 
        + (uv.x - 0.5) * right * fov * aspect 
        + (0.5 - uv.y) * up * fov
    );

    // Sky and Ground
    var color = getSkyColor(rd);
    if (rd.y < 0.0) {
        let t = -cameraPos.y / rd.y;
        if (t > 0.0) {
            let hitPos = cameraPos + rd * t;
            let groundColor = getGroundColor(hitPos);

            // fog
            let fogDist = t / 1000.0;
            let fogAmount = 1.0 - exp(-fogDist * fogDist);
            color = mix(groundColor, getSkyColor(rd), fogAmount);
        }
    }

    return vec4f(color, 1.0);
}
