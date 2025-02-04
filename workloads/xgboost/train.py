# Train a decision tree ensemble.
# The params used are from the XGBoost documentation.

import pandas
import numpy as np
import treelite
import xgboost
from sklearn.model_selection import train_test_split
import os.path
import os.environ
import treelite_runtime

data_dir = os.environ['tmpdir']
full_data_path = os.path.join(data_dir, "HIGGS.csv.gz")
train_path = os.path.join(data_dir, "HIGGS_train.csv.gz")
test_path = os.path.join(data_dir, "HIGGS_test.csv")

print("Reading Data")
if not os.path.exists(train_path):
    df = pandas.read_csv(full_data_path, dtype=np.float32, header=None)
    print("Splitting Data")
    df_train, df_test = train_test_split(df, test_size=0.1, random_state=42, shuffle=True)
    df_train.to_csv(train_path, index=False, header=False, compression="gzip")
    df_test.to_csv(test_path, index=False, header=False)
else:
    df_train = pandas.read_csv(train_path, dtype=np.float32, header=None)

dtrain = xgboost.DMatrix(df_train.iloc[:, 1:29], df_train[0])

print("Beginning Training")
params = {'max_depth':8, 'eta':1, 'objective':'reg:squarederror', 'eval_metric':'rmse'}
bst = xgboost.train(params, dtrain, 1600, [(dtrain, 'train')])
model = treelite.Model.from_xgboost(bst)
toolchain = 'gcc'
print("Saving Model")
modelpath = os.environ['tmpdir']
modelpath = os.path.join(modelpath, '/mymodel.zip')
model.export_srcpkg(platform='unix', toolchain=toolchain, pkgpath=modelpath, libname='libmymodel.so', verbose=True, params={'parallel_comp':30})
