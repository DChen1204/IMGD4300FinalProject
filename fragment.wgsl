
// Structs
struct FragmentInput {
    @location(0) vColor: vec3f,
};
struct FragmentOutput {
    @location(0) color: vec4f,
};

// Main Function
@fragment
fn fs(input: FragmentInput) -> FragmentOutput {
    var output: FragmentOutput;
    output.color = vec4f(input.vColor, 1.0);
    return output;
}