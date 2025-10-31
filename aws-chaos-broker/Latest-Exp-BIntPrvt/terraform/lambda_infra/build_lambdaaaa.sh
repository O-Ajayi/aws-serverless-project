####! /bin/bash

mkdir build_temp
cd build_temp
python3.11 -m venv venv --copies

venv/bin/python3.11 -m pip install -r ../Experiment-Broker-Module/experiment_code/experimentvr/requirements.txt
venv/bin/python3.11 -m pip install ../../../Experiment-Broker-Module/experiment_code > /dev/null
cd venv/lib/python3.11/site-packages

zip -r ../../../../experimentvr_lambda  .
cd -

cp ../../../Experiment-Broker-Module/experiment_code/lambda/handler.py .
zip experimentvr_lambda handler.py


LICENSE  README.md  build_lambdaaaa.sh  build_temp  execution  experiment_code