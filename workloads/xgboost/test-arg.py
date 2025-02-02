import pandas
import numpy as np
import sys
import os.path
import os.environ

model=os.environ['tmpdir']
model=os.path.join(model, '/libmymodel/libmymodel.so')
if len(sys.argv) > 1:
    model=sys.argv[1]
testcsv=os.environ['HOME']
testcsv=os.path.join(testcsv, '/HIGGS_test.csv')
df = pandas.read_csv(testcsv, dtype=np.float32, header=None)
print("Read done")
import treelite_runtime
dtest = treelite_runtime.DMatrix(df.iloc[:, 1:29])
predictor = treelite_runtime.Predictor(model, nthread=1, verbose=True)
print("Predict")
for i in range(1):
    print(i)
    out_pred = predictor.predict(dtest)
#print(out_pred)
