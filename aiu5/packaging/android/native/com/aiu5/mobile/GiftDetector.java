// Runs the same 18-class model locally and applies the desktop stability/NMS rules.
package com.aiu5.mobile;

import ai.onnxruntime.*;
import android.content.res.AssetManager;
import android.graphics.*;
import android.os.SystemClock;
import android.util.Base64;
import org.json.*;
import java.io.*;
import java.nio.FloatBuffer;
import java.util.*;

final class GiftDetector implements AutoCloseable {
    static final String[] NAMES={"cup","knife","bowl","bed","book","scissors","bird","dog","apple","carrot","sword","axe","pickaxe","bow","armor","helmet","leggings","boots"};
    private final OrtEnvironment env=OrtEnvironment.getEnvironment();
    private final OrtSession model;
    private final String input;
    private List<Detection> previous=new ArrayList<>();

    GiftDetector(AssetManager assets) throws Exception {
        ByteArrayOutputStream bytes=new ByteArrayOutputStream();
        try(InputStream stream=assets.open("aiu_gifts18.onnx")) {
            byte[] buffer=new byte[65536]; int n;
            while((n=stream.read(buffer))!=-1) bytes.write(buffer,0,n);
        }
        try(OrtSession.SessionOptions options=new OrtSession.SessionOptions()) {
            options.setIntraOpNumThreads(2); options.setInterOpNumThreads(1);
            model=env.createSession(bytes.toByteArray(),options);
        }
        input=model.getInputNames().iterator().next();
    }

    JSONObject predict(Bitmap frame,String session,int sequence) throws Exception {
        final int side=512;
        float scale=Math.min((float)side/frame.getWidth(),(float)side/frame.getHeight());
        float dx=(side-frame.getWidth()*scale)/2,dy=(side-frame.getHeight()*scale)/2;
        Bitmap padded=Bitmap.createBitmap(side,side,Bitmap.Config.ARGB_8888);
        Canvas canvas=new Canvas(padded); canvas.drawColor(Color.rgb(114,114,114));
        Paint paint=new Paint(Paint.FILTER_BITMAP_FLAG);
        canvas.drawBitmap(frame,null,new RectF(dx,dy,side-dx,side-dy),paint);
        int[] pixels=new int[side*side]; padded.getPixels(pixels,0,side,0,0,side,side); padded.recycle();
        float[] rgb=new float[3*side*side]; int plane=side*side;
        for(int i=0;i<plane;i++) { rgb[i]=((pixels[i]>>16)&255)/255f; rgb[plane+i]=((pixels[i]>>8)&255)/255f; rgb[2*plane+i]=(pixels[i]&255)/255f; }
        List<Detection> detected=new ArrayList<>();
        try(OnnxTensor tensor=OnnxTensor.createTensor(env,FloatBuffer.wrap(rgb),new long[]{1,3,side,side});
            OrtSession.Result result=model.run(Collections.singletonMap(input,tensor))) {
            float[][] out=((float[][][])result.get(0).getValue())[0];
            if(out.length!=22) throw new IOException("识别模型格式不匹配。");
            for(int i=0;i<out[0].length;i++) {
                int cls=0; float confidence=out[4][i];
                for(int c=1;c<NAMES.length;c++) if(out[4+c][i]>confidence) {cls=c;confidence=out[4+c][i];}
                if(confidence<0.45f) continue;
                float x1=Math.max(0,(out[0][i]-out[2][i]/2-dx)/scale),y1=Math.max(0,(out[1][i]-out[3][i]/2-dy)/scale);
                float x2=Math.min(frame.getWidth(),(out[0][i]+out[2][i]/2-dx)/scale),y2=Math.min(frame.getHeight(),(out[1][i]+out[3][i]/2-dy)/scale);
                if(x2>x1 && y2>y1) detected.add(new Detection(cls,confidence,new RectF(x1,y1,x2,y2)));
            }
        }
        detected.sort((a,b)->Float.compare(b.confidence,a.confidence));
        List<Detection> kept=new ArrayList<>();
        for(Detection candidate:detected) {
            boolean suppressed=false;
            for(Detection other:kept) if(candidate.cls==other.cls && iou(candidate.box,other.box)>0.45f) {suppressed=true;break;}
            if(!suppressed) kept.add(candidate);
            if(kept.size()==12) break;
        }
        long now=SystemClock.elapsedRealtime(); List<Detection> unused=new ArrayList<>(previous);
        JSONArray candidates=new JSONArray();
        Bitmap preview=frame.copy(Bitmap.Config.ARGB_8888,true); Canvas overlay=new Canvas(preview); Paint border=new Paint(); border.setStyle(Paint.Style.STROKE); border.setStrokeWidth(2);
        for(Detection candidate:kept) {
            Detection best=null; float overlap=0.35f;
            for(Detection old:unused) if(old.cls==candidate.cls && now-old.last<1200 && iou(candidate.box,old.box)>=overlap) {best=old;overlap=iou(candidate.box,old.box);}
            if(best!=null) { unused.remove(best); candidate.id=best.id; candidate.hits=best.hits+1; candidate.first=best.first; }
            else {candidate.id=UUID.randomUUID().toString();candidate.hits=1;candidate.first=now;}
            candidate.last=now; boolean stable=candidate.hits>=3 && now-candidate.first>=600;
            JSONObject entry=new JSONObject().put("id",candidate.id).put("class_id",candidate.cls).put("class_name",NAMES[candidate.cls]).put("confidence",candidate.confidence).put("stable",stable);
            entry.put("box",new JSONArray(new double[]{candidate.box.left,candidate.box.top,candidate.box.right,candidate.box.bottom})); candidates.put(entry);
            border.setColor(stable?Color.rgb(110,215,130):Color.rgb(220,170,80)); overlay.drawRect(candidate.box,border);
        }
        previous=kept;
        ByteArrayOutputStream jpeg=new ByteArrayOutputStream(); preview.compress(Bitmap.CompressFormat.JPEG,75,jpeg); preview.recycle();
        return new JSONObject().put("session_id",session).put("status","ready").put("sequence",sequence).put("device","手机本地 · CPU").put("width",frame.getWidth()).put("height",frame.getHeight()).put("frame_jpeg",Base64.encodeToString(jpeg.toByteArray(),Base64.NO_WRAP)).put("candidates",candidates);
    }

    private static float iou(RectF a,RectF b) {
        float intersection=Math.max(0,Math.min(a.right,b.right)-Math.max(a.left,b.left))*Math.max(0,Math.min(a.bottom,b.bottom)-Math.max(a.top,b.top));
        float union=a.width()*a.height()+b.width()*b.height()-intersection;
        return union>0?intersection/union:0;
    }
    @Override public void close() throws OrtException {model.close();previous.clear();}
    private static final class Detection {
        final int cls; final float confidence; final RectF box;
        String id; int hits; long first,last;
        Detection(int cls,float confidence,RectF box) {this.cls=cls;this.confidence=confidence;this.box=box;}
    }
}
