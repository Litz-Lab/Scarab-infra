import pandas
import numpy as np
import sys

model='/home/dcuser/libmymodel/libmymodel.so'
if len(sys.argv) > 1:
    model=sys.argv[1]
df = pandas.read_csv("/home/dcuser/HIGGS_test.csv", dtype=np.float32, header=None)
print("Read done")
import treelite_runtime
dtest = treelite_runtime.DMatrix(df.iloc[:, 1:29])
predictor = treelite_runtime.Predictor(model, nthread=1, verbose=True)
print("Predict")
for i in range(10):
    print(i)
    out_pred = predictor.predict(dtest)
#print(out_pred)
