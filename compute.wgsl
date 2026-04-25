
// Structs
struct Boid {
    pos: vec2f,
    vel: vec2f,
};
struct Uniforms {
    time: f32,
    deltaTime: f32,
    width: f32,
    height: f32,
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
    pad1: f32,
    pad2: f32,
    pad3: f32,
};

// Bindings
@group(0) @binding(0) var<storage, read> boidsIn: array<Boid>;
@group(0) @binding(1) var<storage, read_write> boidsOut: array<Boid>;
@group(0) @binding(2) var<uniform> uniforms: Uniforms;

// Helper Functions

// Calculate the shortest distance between two points
fn torodialDistance(a: vec2f, b: vec2f) -> vec2f {
    var diff = b - a;

    // Wrap around the edges
    if (diff.x > uniforms.width * 0.5) { diff.x -= uniforms.width; }
    if (diff.x < -uniforms.width * 0.5) { diff.x += uniforms.width; }
    if (diff.y > uniforms.height * 0.5) { diff.y -= uniforms.height; }
    if (diff.y < -uniforms.height * 0.5) { diff.y += uniforms.height; }

    return diff;
}

// Limit a vector's magnitude to the max value
fn limit(vec: vec2f, max: f32) -> vec2f {
    let lengthSq = dot(vec, vec);
    if (lengthSq > max * max) {
        return normalize(vec) * max;
    }
    return vec;
}

// Wrap a position around the canvas edges
fn wrapPosition(pos: vec2f) -> vec2f {
    var p = pos;
    if (p.x < 0.0) { p.x += uniforms.width; }
    if (p.x >= uniforms.width) { p.x -= uniforms.width; }
    if (p.y < 0.0) { p.y += uniforms.height; }
    if (p.y >= uniforms.height) { p.y -= uniforms.height; }
    return p;
}

// Main Function
@compute @workgroup_size(64)
fn cs(@builtin(global_invocation_id) global_id: vec3u) {
    let idx = global_id.x;

    // Limit the number of boids
    if (idx >= u32(uniforms.numBoids)) {
        return;
    }

    let currentBoid = boidsIn[idx];

    // Force vectors and counters
    var separationForce = vec2f(0.0, 0.0);
    var alignmentForce = vec2f(0.0, 0.0);
    var cohesionForce = vec2f(0.0, 0.0);
    var separationCount = 0.0;
    var alignmentCount = 0.0;
    var cohesionCount = 0.0;

    // Check every neighbor
    for (var i = 0u; i < u32(uniforms.numBoids); i++) {

        // Skip self
        if (i == idx) {
            continue;
        }

        // Check distance between boids
        let otherBoid = boidsIn[i];
        let diff = torodialDistance(currentBoid.pos, otherBoid.pos);
        let dist = length(diff);

        // Separation
        if (dist < uniforms.separationRadius && dist > 0.0) {
            separationForce += -normalize(diff) / dist;
            separationCount += 1.0;
        }

        // Alignment
        if (dist < uniforms.alignmentRadius) {
            alignmentForce += otherBoid.vel;
            alignmentCount += 1.0;
        }

        // Cohesion
        if (dist < uniforms.cohesionRadius) {
            cohesionForce += diff;
            cohesionCount += 1.0;
        }

    }

    // Process Separation
    if (separationCount > 0.0) {
        separationForce /= separationCount;
        separationForce = normalize(separationForce) * uniforms.maxSpeed;
        separationForce -= currentBoid.vel;
        separationForce = limit(separationForce, uniforms.maxForce);
    }

    // Process Alignment
    if (alignmentCount > 0.0) {
        alignmentForce /= alignmentCount;
        alignmentForce = normalize(alignmentForce) * uniforms.maxSpeed;
        alignmentForce -= currentBoid.vel;
        alignmentForce = limit(alignmentForce, uniforms.maxForce);
    }

    // Process Cohesion
    if (cohesionCount > 0.0) {
        cohesionForce /= cohesionCount;
        cohesionForce = normalize(cohesionForce) * uniforms.maxSpeed;
        cohesionForce -= currentBoid.vel;
        cohesionForce = limit(cohesionForce, uniforms.maxForce);
    }

    // Apply weight to new velocity
    var newVel = currentBoid.vel;
    newVel += separationForce * uniforms.separationWeight;
    newVel += alignmentForce * uniforms.alignmentWeight;
    newVel += cohesionForce * uniforms.cohesionWeight;

    // Mouse interaction
    if (uniforms.mouseActive > 0.5) {
        let mousePos = vec2f(uniforms.mouseX, uniforms.mouseY);
        let diff = torodialDistance(currentBoid.pos, mousePos);
        let dist = length(diff);
        let mouseRadius = 150.0;

        if (dist < mouseRadius && dist > 0.0) {
            var mouseForce = vec2f(0.0);
            let strength = 1.0 - (dist / mouseRadius);

            // Repel
            if (uniforms.mouseMode < 0.5) {
                mouseForce = -normalize(diff) * strength * 800.0;
            }
            // Attract
            else {
                let desiredVel = normalize(diff) * uniforms.maxSpeed;
                mouseForce = desiredVel - currentBoid.vel;
                mouseForce = limit(mouseForce, uniforms.maxForce * 2.0);
            }

            newVel += mouseForce;
        }
    }

    newVel = limit(newVel, uniforms.maxSpeed);

    // Update position
    var newPos = currentBoid.pos + newVel * uniforms.deltaTime;
    newPos = wrapPosition(newPos);

    boidsOut[idx] = Boid(newPos, newVel);

}