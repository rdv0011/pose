import coremltools
from coremltools.proto import FeatureTypes_pb2 as ft

caffeeModel = 'pose_iter_160000.caffemodel'
protoFile = 'pose_deploy_linevec_faster_4_stages_fixed_size.prototxt'
inputFilesBaseDir = '../../../models/pose/mpi/'
coreml_model = coremltools.converters.caffe.convert((inputFilesBaseDir + caffeeModel, inputFilesBaseDir + protoFile),
														image_input_names = 'image',
														image_scale = 1.0/255)
spec = coreml_model.get_spec()

def _convert_multiarray_to_float32(feature):
  if feature.type.HasField('multiArrayType'):
    feature.type.multiArrayType.dataType = ft.ArrayFeatureType.FLOAT32

for input_ in spec.description.input:
    _convert_multiarray_to_float32(input_)
for output_ in spec.description.output:
    _convert_multiarray_to_float32(output_)

coreml_model = coremltools.models.MLModel(spec)

coreml_model.save('PoseModel.mlmodel')
