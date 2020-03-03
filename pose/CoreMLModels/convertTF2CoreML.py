import coremltools
from coremltools.proto import FeatureTypes_pb2 as ft
import sys
import argparse
from pathlib import Path
import tfcoreml as tf_converter


parser = argparse.ArgumentParser(description="Tools to convert frozen TensorFlow model file to CoreML file.")
parser.add_argument("--frozen_pb_file", type=str, default="./model.pb", help="Path of to a frozen model file.")
parser.add_argument("--output_coreml_file", type=str, default="./model.pb", help="Path of to a frozen model file.")
parser.add_argument("--input_node_name", type=str, default="image", help="Name of input node.")
parser.add_argument("--output_node_name", type=str, default="out", help="Name of output node.")

args = parser.parse_args()

# modelName = "".join(arg1) # .pb frozen model file name in the current directory
tf_model_path = Path(args.frozen_pb_file)

model = tf_converter.convert(tf_model_path = tf_model_path,
                     mlmodel_path = args.output_coreml_file,
                     image_input_names = ["%s:0" % args.input_node_name],
                     output_feature_names = ['%s:0' % args.output_node_name])

spec = model.get_spec()

def _convert_multiarray_to_float32(feature):
  if feature.type.HasField('multiArrayType'):
    feature.type.multiArrayType.dataType = ft.ArrayFeatureType.FLOAT32

for input_ in spec.description.input:
    _convert_multiarray_to_float32(input_)
for output_ in spec.description.output:
    _convert_multiarray_to_float32(output_)

model = coremltools.models.MLModel(spec)
model.save(args.output_coreml_file)