varying vec3 fragmentPosition;

#ifdef VERTEX

uniform mat4 modelToWorld;
uniform mat4 modelToClip;

layout (location = 0) in vec3 VertexPosition;

void vertexmain() {
	fragmentPosition = (modelToWorld * vec4(VertexPosition, 1.0)).xyz;
	gl_Position = modelToClip * vec4(VertexPosition, 1.0);
}

#endif

#ifdef PIXEL

out vec4 dist;

uniform vec3 cameraPosition;

void pixelmain() {
	float outputValue = distance(cameraPosition, fragmentPosition);
	dist = vec4(vec3(outputValue), 1.0);
}

#endif
