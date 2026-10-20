"""Convert the existing 18-class weights and verify numerical parity for Android inference."""
from pathlib import Path
import argparse, json, shutil, tempfile
import numpy as np
import onnx, onnxruntime as ort, torch
from ultralytics import YOLO

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--weights',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args()
    torch.set_num_threads(2)
    with tempfile.TemporaryDirectory(prefix='aiu5-onnx-') as folder:
        source=Path(folder)/'aiu_gifts18.pt';shutil.copy2(args.weights,source)
        model=YOLO(source)
        names=['cup','knife','bowl','bed','book','scissors','bird','dog','apple','carrot','sword','axe','pickaxe','bow','armor','helmet','leggings','boots']
        if list(model.names.values())!=names: raise ValueError('Model must use the original ordered 18 classes')
        result=model.export(format='onnx',imgsz=512,opset=17,simplify=False,dynamic=False,nms=False,device='cpu')
        onnx.checker.check_model(onnx.load(result))
        session=ort.InferenceSession(str(result),providers=['CPUExecutionProvider'])
        sample=np.random.default_rng(108).random((1,3,512,512),dtype=np.float32)
        with torch.no_grad():
            expected=model.model(torch.from_numpy(sample))
            if isinstance(expected,(list,tuple)): expected=expected[0]
            expected=expected.detach().numpy()
        actual=session.run(None,{session.get_inputs()[0].name:sample})[0]
        if actual.shape!=(1,22,5376) or not np.allclose(expected,actual,rtol=.001,atol=.003): raise ValueError('Android model parity check failed')
        args.output.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(result,args.output)
        args.output.with_suffix('.verification.json').write_text(json.dumps({'classes':names,'input':[1,3,512,512],'output':list(actual.shape),'max_abs_error':float(np.max(np.abs(expected-actual)))},indent=2)+'\n',encoding='utf-8')
    print(args.output)

if __name__=='__main__': main()
