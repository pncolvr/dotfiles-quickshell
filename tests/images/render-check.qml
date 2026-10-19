import QtQuick
import QtQuick.Window
import QtTest

TestCase {
    name:"CroppedImagePixels"
    when:windowShown
    width:1000; height:600
    Canvas {
        id:rendered
        width:1000; height:600
        visible:false
        property var pixels:null
        property url imageSource:"@CROP_RENDERED@"
        onAvailableChanged: if(available) loadImage(imageSource)
        onImageLoaded: requestPaint()
        onPaint: {
            const ctx=getContext("2d")
            ctx.reset(); ctx.scale(1 / Screen.devicePixelRatio,1 / Screen.devicePixelRatio)
            ctx.drawImage(imageSource,0,0,1000,600)
            pixels=ctx.getImageData(0,0,width,height).data
        }
    }
    function pixel(x,y) {
        const offset=(y*1000+x)*4, data=rendered.pixels
        return {r:data[offset],g:data[offset+1],b:data[offset+2],a:data[offset+3]}
    }
    function test_pixels() {
        tryVerify(()=>!!rendered.pixels)
        // Green ring/exterior must disappear in both large art and 40-pixel avatar.
        let green=0, softEdge=0
        for(let y=10;y<410;y++) for(let x=100;x<500;x++) {
            const color=pixel(x,y)
            if(color.a>25 && color.g>color.r+38 && color.g>color.b+38) green++
            if(color.a>0 && color.a<255) softEdge++
        }
        compare(green,0)
        verify(softEdge>100,"large circular masks preserve fractional edge alpha instead of thresholding to a jagged silhouette (fractional pixels=" + softEdge + ", DPR=" + Screen.devicePixelRatio + ")")
        compare(pixel(100,10).a,0)
        verify(pixel(300,260).r>150)
        verify(pixel(300,190).r<20,"enclosed black portrait detail is preserved")
        compare(pixel(10,10).a,0)
        let smallSoftEdge=0
        for(let y=10;y<50;y++) for(let x=10;x<50;x++) {
            const color=pixel(x,y)
            if(color.a>0 && color.a<255) smallSoftEdge++
            verify(color.a<25 || color.g<=color.r+38 || color.g<=color.b+38,"no green fringe in small avatar at " + x + "," + y)
        }
        verify(smallSoftEdge>10,"small avatar masks preserve antialiasing too (fractional pixels=" + smallSoftEdge + ")")
        // Unframed artwork remains opaque and rectangular.
        compare(pixel(550,90).a,255)
        compare(pixel(849,239).a,255)
        verify(pixel(700,160).r>100 && pixel(700,160).g<100,"ordinary artwork keeps its source colors")
        compare(pixel(550,280).a,0)
        verify(pixel(560,290).r>150,"padding mask fills its avatar at the device scale")
        let framePixels=0
        for(let y=280;y<460;y++) for(let x=700;x<950;x++) {
            const color=pixel(x,y)
            if(color.a>10 && (color.g>color.r+5 || color.b>color.r+5)) framePixels++
        }
        compare(framePixels,0,"blurred media backgrounds also exclude the embedded frame and exterior")
        verify(pixel(825,420).a>10 && pixel(825,420).r>pixel(825,420).g+5,"the cropped background remains visible")
    }
}
