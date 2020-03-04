# Multi person Caffe model file
OPENPOSE_URL="http://posefs1.perception.cs.cmu.edu/OpenPose/models/"
POSE_FOLDER="pose/"
MPI_FOLDER=${POSE_FOLDER}"mpi/"
MPI_MODEL=${MPI_FOLDER}"pose_iter_160000.caffemodel"
MPI_LOCAL="multiPoseModel/mpi"
wget -c ${OPENPOSE_URL}${MPI_MODEL} -P ${MPI_LOCAL}
# Single person TensorFlow model file
SINGLE_PERSON_URL="https://github.com/tucan9389/PoseEstimation-CoreML/raw/master/models/cpm_model/model.pb"
wget -c ${SINGLE_PERSON_URL} -P "singlePoseModel/"