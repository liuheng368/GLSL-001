precision highp float;
varying lowp vec2 varyTextureCoord;
uniform sampler2D textureMap;

void main() {
    lowp vec4 temp = texture2D(textureMap, varyTextureCoord);
    gl_FragColor = temp;
    
}
