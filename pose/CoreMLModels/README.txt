To create Core ML model do the following:
1) Install python and CoreML tools: https://apple.github.io/coremltools/generated/coremltools.converters.caffe.convert.html
2) Run models/getModels.sh to get the original openpose models
3) run python convertModel.py

The above mentioned script has hardcoded values to the file pose_deploy_linevec_faster_4_stages_fixed_size.prototxt and model file pose_iter_160000.caffemodel.
They could be changed to other model but please do not forget to change the .prototxt file to have fixed size of the input image:
input_dim: 512 (corresponds to the with of the input. Could be reasonable value that fits the real input)
input_dim: 512 (corresponds to the height of the input. Could be reasonable value that fits the real input)

The description of the network output. The output is one image which has input_image_width / 8, input_image_height / 8
// Mapping between matrix index and the body part
const std::map<unsigned int, std::string> POSE_MPI_BODY_PARTS {
	{0,  "Head"},
	{1,  "Neck"},
	{2,  "RShoulder"},
	{3,  "RElbow"},
	{4,  "RWrist"},
	{5,  "LShoulder"},
	{6,  "LElbow"},
	{7,  "LWrist"},
	{8,  "RHip"},
	{9,  "RKnee"},
	{10, "RAnkle"},
	{11, "LHip"},
	{12, "LKnee"},
	{13, "LAnkle"},
	{14, "Chest"},
	{15, "Background"}
};

// POSE_NUMBER_BODY_PARTS
// POSE_NUMBER_BODY_PARTS equivalent to size of std::map POSE_BODY_XX_BODY_PARTS - 1 (removing background)
#define POSE_MPI_PAIRS_RENDER_GPU \
0,1,   1,2,   2,3,   3,4,   1,5,   5,6,   6,7,   1,14,  14,8,  8,9,  9,10,  14,11, 11,12, 12,13

// POSE_MAP_INDEX
// MPI_15
std::vector<unsigned int>{
	0,1, 2,3, 4,5, 6,7, 8,9, 10,11, 12,13, 14,15, 16,17, 18,19, 20,21, 22,23, 24,25, 26,27
}