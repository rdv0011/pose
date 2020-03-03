import coremltools
from coremltools.proto import FeatureTypes_pb2 as ft
from coremltools.models.neural_network import flexible_shape_utils
import argparse
from pathlib import Path

parser = argparse.ArgumentParser(description="Tools for convert cafee to CoreML.")
parser.add_argument("--caffe_model_file", type=str, default="./model.cafeemodel", help="Path to a Cafee model.")
parser.add_argument("--proto_file", type=str, default="image", help="Path to a proto file.")
parser.add_argument("--output_model_file", type=str, default="model.mlmodel", help="Path of to an output CoreML model.")
parser.add_argument("--input_node_names", type=str, default="image", help="Name of an input node.")
parser.add_argument("--output_node_name", type=str, default="net_output", help="Name of an output node.")

args = parser.parse_args()

coreml_model = coremltools.converters.caffe.convert((args.caffe_model_file, args.proto_file),
														image_input_names = args.input_node_names,
														image_scale = 1.0/255)
spec = coreml_model.get_spec()

def _convert_multiarray_to_float32(feature):
  if feature.type.HasField('multiArrayType'):
    feature.type.multiArrayType.dataType = ft.ArrayFeatureType.FLOAT32

for input_ in spec.description.input:
    _convert_multiarray_to_float32(input_)
for output_ in spec.description.output:
    _convert_multiarray_to_float32(output_)

# Set the output shape dimensions
# For MPI15 there are 15 body parts + one background layer + 28 (14 * 2 for x and y) PAFs layers
# Which gives 44 layers in total and the output shape is 64 by 64 
shape_range = flexible_shape_utils.NeuralNetworkMultiArrayShapeRange()
shape_range.add_channel_range((44, 44))
shape_range.add_width_range((48, 48))
shape_range.add_height_range((48, 48))
flexible_shape_utils.update_multiarray_shape_range(spec, feature_name=args.output_node_name, shape_range=shape_range)

coreml_model = coremltools.models.MLModel(spec)

coreml_model.save(args.output_model_file)
