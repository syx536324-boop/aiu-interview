// Owns permission-gated Camera2 capture; frames and inference remain on the phone.
package com.aiu5.mobile;

import android.Manifest;
import android.app.Activity;
import android.content.Context;
import android.content.pm.PackageManager;
import android.graphics.*;
import android.hardware.camera2.*;
import android.media.Image;
import android.media.ImageReader;
import android.os.*;
import android.util.Size;
import android.view.Surface;
import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.*;
import org.json.JSONObject;
import java.nio.ByteBuffer;
import java.util.*;
import java.util.concurrent.*;
import java.util.concurrent.atomic.*;

public final class AiuGiftCamera extends GodotPlugin {
    private static final int PERMISSION=51818;
    private final ExecutorService worker=Executors.newSingleThreadExecutor();
    private final AtomicInteger generation=new AtomicInteger();
    private final AtomicBoolean processing=new AtomicBoolean();
    private volatile String session="";
    private volatile boolean foreground=true;
    private volatile CameraDevice camera;
    private CameraCaptureSession capture;
    private ImageReader reader;
    private HandlerThread thread;
    private GiftDetector detector;
    private long lastFrame;
    private int sequence;

    public AiuGiftCamera(Godot godot) {super(godot);}
    @Override public String getPluginName() {return "AiuGiftCamera";}
    @Override public Set<SignalInfo> getPluginSignals() {return Collections.singleton(new SignalInfo("camera_snapshot",String.class));}

    @UsedByGodot public void openCamera(String id) {
        closeCamera(); session=id; sequence=0;
        runOnUiThread(()-> {
            Activity activity=getActivity(); if(activity==null) return;
            if(activity.checkSelfPermission(Manifest.permission.CAMERA)!=PackageManager.PERMISSION_GRANTED) {
                activity.requestPermissions(new String[]{Manifest.permission.CAMERA},PERMISSION);
            } else startCapture();
        });
    }
    @Override public void onMainRequestPermissionsResult(int request,String[] permissions,int[] results) {
        if(request!=PERMISSION || session.isEmpty()) return;
        if(results.length>0 && results[0]==PackageManager.PERMISSION_GRANTED) startCapture();
        else error(session,"未授予摄像头权限。可在系统设置中允许相机权限后重新开启赐予。");
    }

    private void startCapture() {
        if(session.isEmpty() || !foreground) return;
        final int version=generation.get(); final String id=session;
        worker.execute(()-> {
            try {
                if(detector==null) detector=new GiftDetector(getActivity().getAssets());
                if(version==generation.get() && !session.isEmpty()) runOnUiThread(()->openDevice(version,id));
            } catch(Exception e) {if(version==generation.get()) error(id,"手机识别模型加载失败："+e.getMessage());}
        });
    }
    private void openDevice(int version,String id) {
        if(version!=generation.get() || !foreground) return;
        try {
            CameraManager manager=(CameraManager)getActivity().getSystemService(Context.CAMERA_SERVICE);
            String selected=null;
            for(String candidate:manager.getCameraIdList()) {
                if(selected==null) selected=candidate;
                Integer facing=manager.getCameraCharacteristics(candidate).get(CameraCharacteristics.LENS_FACING);
                if(facing!=null && facing==CameraCharacteristics.LENS_FACING_BACK) {selected=candidate;break;}
            }
            if(selected==null) throw new IllegalStateException("没有可用摄像头。");
            CameraCharacteristics properties=manager.getCameraCharacteristics(selected);
            Size[] sizes=properties.get(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP).getOutputSizes(ImageFormat.YUV_420_888);
            Size size=sizes[0]; long best=Long.MAX_VALUE;
            for(Size candidate:sizes) {
                long score=Math.abs((long)candidate.getWidth()*candidate.getHeight()-640*480);
                if(score<best) {best=score;size=candidate;}
            }
            final int sensor=properties.get(CameraCharacteristics.SENSOR_ORIENTATION);
            thread=new HandlerThread("AIU5Camera");thread.start(); Handler handler=new Handler(thread.getLooper());
            reader=ImageReader.newInstance(size.getWidth(),size.getHeight(),ImageFormat.YUV_420_888,3);
            reader.setOnImageAvailableListener(source->frame(source,version,id,sensor),handler);
            if(getActivity().checkSelfPermission(Manifest.permission.CAMERA)!=PackageManager.PERMISSION_GRANTED) throw new SecurityException("摄像头权限已被收回。");
            manager.openCamera(selected,new CameraDevice.StateCallback() {
                @Override public void onOpened(CameraDevice device) {
                    if(version!=generation.get()) {device.close();return;}
                    camera=device;
                    try {
                        final Surface output=reader.getSurface();
                        device.createCaptureSession(Collections.singletonList(output),new CameraCaptureSession.StateCallback() {
                            @Override public void onConfigured(CameraCaptureSession configured) {
                                if(version!=generation.get()) {configured.close();return;}
                                capture=configured;
                                try {
                                    CaptureRequest.Builder request=device.createCaptureRequest(CameraDevice.TEMPLATE_PREVIEW);
                                    request.addTarget(output);request.set(CaptureRequest.CONTROL_AF_MODE,CaptureRequest.CONTROL_AF_MODE_CONTINUOUS_PICTURE);
                                    configured.setRepeatingRequest(request.build(),null,handler);
                                } catch(Exception e) {error(id,"相机画面启动失败："+e.getMessage());}
                            }
                            @Override public void onConfigureFailed(CameraCaptureSession failed) {if(version==generation.get()) error(id,"相机不支持当前画面格式。");}
                        },handler);
                    } catch(Exception e) {error(id,"相机初始化失败："+e.getMessage());}
                }
                @Override public void onDisconnected(CameraDevice device) {device.close();if(version==generation.get()) error(id,"摄像头已断开，请关闭后重试。");}
                @Override public void onError(CameraDevice device,int code) {device.close();if(version==generation.get()) error(id,"摄像头不可用（"+code+"），请关闭其他占用相机的应用。");}
            },handler);
        } catch(Exception e) {if(version==generation.get()) error(id,"无法打开手机摄像头："+e.getMessage());}
    }

    private void frame(ImageReader source,int version,String id,int sensor) {
        Image image;
        try {image=source.acquireLatestImage();} catch(IllegalStateException e) {return;}
        if(image==null) return;
        if(version!=generation.get() || SystemClock.elapsedRealtime()-lastFrame<250 || !processing.compareAndSet(false,true)) {image.close();return;}
        lastFrame=SystemClock.elapsedRealtime();
        worker.execute(()-> {
            Bitmap bitmap=null;
            try {
                if(version!=generation.get()) return;
                bitmap=bitmap(image);
                int display=getActivity().getWindowManager().getDefaultDisplay().getRotation();
                int degrees=new int[]{0,90,180,270}[display]; int rotation=(sensor-degrees+360)%360;
                if(rotation!=0) {Matrix transform=new Matrix();transform.postRotate(rotation);Bitmap rotated=Bitmap.createBitmap(bitmap,0,0,bitmap.getWidth(),bitmap.getHeight(),transform,true);if(rotated!=bitmap) bitmap.recycle();bitmap=rotated;}
                JSONObject result=detector.predict(bitmap,id,++sequence);
                if(version==generation.get() && foreground) emitSignal("camera_snapshot",result.toString());
            } catch(Exception e) {if(version==generation.get()) error(id,"手机识别暂时失败："+e.getMessage());}
            finally {image.close();if(bitmap!=null) bitmap.recycle();processing.set(false);}
        });
    }
    private static Bitmap bitmap(Image image) {
        int width=image.getWidth(),height=image.getHeight();int[] rgb=new int[width*height];Image.Plane[] planes=image.getPlanes();
        ByteBuffer y=planes[0].getBuffer(),u=planes[1].getBuffer(),v=planes[2].getBuffer();
        int y0=y.position(),u0=u.position(),v0=v.position();
        for(int row=0;row<height;row++) for(int col=0;col<width;col++) {
            int luminance=(y.get(y0+row*planes[0].getRowStride()+col*planes[0].getPixelStride())&255)-16;
            int blue=(u.get(u0+(row/2)*planes[1].getRowStride()+(col/2)*planes[1].getPixelStride())&255)-128;
            int red=(v.get(v0+(row/2)*planes[2].getRowStride()+(col/2)*planes[2].getPixelStride())&255)-128;
            int r=(298*luminance+409*red+128)>>8,g=(298*luminance-100*blue-208*red+128)>>8,b=(298*luminance+516*blue+128)>>8;
            rgb[row*width+col]=0xff000000|(clamp(r)<<16)|(clamp(g)<<8)|clamp(b);
        }
        return Bitmap.createBitmap(rgb,width,height,Bitmap.Config.ARGB_8888);
    }
    private static int clamp(int value) {return Math.max(0,Math.min(255,value));}
    private void error(String id,String text) {
        try {emitSignal("camera_snapshot",new JSONObject().put("session_id",id).put("status","error").put("message",text).toString());} catch(Exception ignored) {}
    }
    @UsedByGodot public boolean isCameraOpen() {return camera!=null;}
    @UsedByGodot public void closeCamera() {
        generation.incrementAndGet();session="";
        runOnUiThread(()-> {
            if(capture!=null) {capture.close();capture=null;}
            if(camera!=null) {camera.close();camera=null;}
            if(reader!=null) {reader.close();reader=null;}
            if(thread!=null) {thread.quitSafely();thread=null;}
        });
        if(!worker.isShutdown()) worker.execute(()-> {if(detector!=null) {try {detector.close();} catch(Exception ignored) {} detector=null;}});
    }
    @Override public void onMainPause() {foreground=false;closeCamera();}
    @Override public void onMainResume() {foreground=true;}
    @Override public void onMainDestroy() {closeCamera();worker.shutdown();}
}
