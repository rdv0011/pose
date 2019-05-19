# Human Pose estimation
This framework helps to estimate the human pose on an image. The parts of the human body used in this project are shown on the follwoing image:

<img src="sample-images/vitruvian_shape.png?sanitize=true&raw=true" />

| For the demo purposes I took images with myself)                 | The result human pose estimation drawn over the original image   |
| ---------------------------------------------------------------------------------------------------------------------------- |:---------------------------------------------------------------------------:|
| <img src="pose/poseDemo/Assets.xcassets/sample-pose1-resized.imageset/sample-pose1-resized.png" /> | <img src="sample-images/pose-result.png" />                                                        |

## Preparing the model
To start using the framework a Core ML model is needed to be created. This model is based on one from the [openpose project](https://github.com/CMU-Perceptual-Computing-Lab/openpose). To create a model do the following:
1) Install Python and CoreML tools: https://apple.github.io/coremltools/generated/coremltools.converters.caffe.convert.html
2) Run models/getModels.sh from [Open Pose](https://github.com/CMU-Perceptual-Computing-Lab/openpose) to get the original openpose models
3) Create a link to the models directory. Let's assume that the pose framework project and openpose project are in the home directory, then command to create a link would be the following:

`ln -s ~/openpose/models ~/models`

4) Go to the ~/pose/pose/CoreMLModels and run the following command:

`python convertModel.py`

The above mentioned script contains hardcoded values to the file pose_deploy_linevec_faster_4_stages_fixed_size.prototxt and model file pose_iter_160000.caffemodel.
They could be changed to some other model but please do not forget to change the .prototxt file to have fixed size of the input image:
input_dim: 512  - corresponds to the with of the NN input.
input_dim: 512  - corresponds to the height of the NN input.

Any values will work but the best results could be achieved if an aspect ratio matches the one that an original image has. Also it should be taken into account that bigger values will affect the performance more.

## Neural network output details
The output of the MPI15 model is a group of matrices whith dimensions `(input_image_width / 8, input_image_height / 8)`. Each element in the matrix has float type. Mapping between matrix index in the output and the body part:
```
POSE_MPI_BODY_PARTS {
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
```

### Heatmaps and PAFs
There are two types of output matices in the MPI15 model. The ones that represent heatmaps and the others that represent PAFs. Each heat matrix corresponds to one joint part which is 15 in total. The PAF matices represent body connections. For each body connection there is X and Y matrix which is 28 in total (14 + 14). The total amount of matrices including so called a background one is 44.

## Demo project
The repository also contains a demo project 'poseDemo' that demonstrates usage of the framework.

| Sample                                                                             | Images                                                                                              |
| --------------------------------------------------------------- |:---------------------------------------------------------------------------:|
| Human pose result:                                                          | Heatmaps combined into one image. Each joint has its own color:|
| <img src="sample-images/pose-result.png?sanitize=true&raw=true" /> |  <img src="sample-images/heatmaps.png?sanitize=true&raw=true" />                   |
| PAFs combined into one image:                                      |   All heatmap candidates. Each candidate has its own confidence which defines its opacity on the image: |
| <img src="sample-images/PAFs.png?sanitize=true&raw=true" />           | <img src="sample-images/heatmap-candidates.png?sanitize=true&raw=true" /> |
| Closer look at heatmap candidates corresponding a head:| Closer look at heatmap candidates corresponding to a neck:|
| <img src="sample-images/head-heatmap-candidates.png?sanitize=true&raw=true" /> | <img src="sample-images/neck-heatmap-candidates.png?sanitize=true&raw=true" /> |
|  PAF matrix which corresponds to a head neck connection candidate. The head, neck heatmap joints are shown also on the image: | PAF matrix which corresponds to a LShoulder, LElbow connection candidate. The LShoulder-LElbow heatmap joints are shown also on the image:|
| <img src="sample-images/PAF-X-head-neck-connection.png?sanitize=true&raw=true" /> | <img src="sample-images/PAF-X-LShoulder-LElbow-connection.png?sanitize=true&raw=true" />|

## Performance


