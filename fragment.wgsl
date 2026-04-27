
// Structs
struct FragmentInput {
    @location(0) vColor: vec3f,
    @location(1) vNormal: vec3f,
};
struct FragmentOutput {
    @location(0) color: vec4f,
};

// Main Function
@fragment
fn fs(input: FragmentInput) -> FragmentOutput {
    
    // Lighting
    let sunDir = normalize(vec3f(0.3, 1.0, 0.5));
    let diffuse = max(dot(normalize(input.vNormal), sunDir), 0.0);
    let ambient = 0.4;
    let light = ambient + diffuse;

    let color = input.vColor * light;
    var output: FragmentOutput;
    output.color = vec4f(color, 1.0);
    return output;

}