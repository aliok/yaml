#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import logging
from typing import Dict, Union
import json

import boto3
import cv2
from cloudevents.http import CloudEvent
from cloudevents.conversion import to_json
import numpy as np

import kserve
from kserve import InferRequest, InferResponse, InferInput
from kserve.protocol.grpc.grpc_predict_v2_pb2 import ModelInferResponse

logging.basicConfig(level=kserve.constants.KSERVE_LOGLEVEL)

session = boto3.Session()
client = session.client('s3', endpoint_url='http://minio-service:9000', aws_access_key_id='minio',
                        aws_secret_access_key='minio123')
digits_bucket = 'digits'


def image_transform2(image):
    img = cv2.imread(image, cv2.IMREAD_GRAYSCALE)
    g = cv2.resize(255 - img, (28, 28))
    g = g.flatten() / 255.0
    return g.tolist()

def image_transform(image):
    img = cv2.imread(image, cv2.IMREAD_GRAYSCALE)
    g = cv2.resize(img, (8, 8))
    g = g.flatten() / 255.0 * 16
    return g.tolist()

class ImageTransformer(kserve.Model):
    def __init__(self, name: str, predictor_host: str):
        super().__init__(name)
        self.predictor_host = predictor_host
        self._key = None
        self.model_name = name

    async def preprocess(self, inputs: Union[Dict, CloudEvent, InferRequest],
                         headers: Dict[str, str] = None) -> Union[Dict, InferRequest]:
        logging.info("Received inputs %s", inputs)
        cloud_event = inputs.get_data()
        evt = json.loads(cloud_event)
        logging.info("Received event %s", evt)

        if evt['EventName'] == 's3:ObjectCreated:Put':
            bucket = evt['Records'][0]['s3']['bucket']['name']
            key = evt['Records'][0]['s3']['object']['key']
            self._key = key

            logging.info('Event for bucket=' + bucket + "; key=" + key)
            client.download_file(bucket, key, '/tmp/' + key)
            logging.info('Downloaded file')

            img_data = image_transform('/tmp/' + key)
            logging.info('Image data' + img_data.__repr__())
            img_input = np.asarray([img_data])
            tensor = np.float32(img_input)
            logging.info('Tensor' + tensor.__repr__())

            infer_input = InferInput(name="predict", datatype='FP32', shape=tensor.shape)
            infer_input.set_data_from_numpy(tensor, False)
            logging.info('Infer input' + infer_input.__repr__())
            infer_request = InferRequest(model_name=self.model_name, infer_inputs=[infer_input])
            logging.info('Infer request' + infer_request.__repr__())

            return infer_request

        raise Exception("unknown event")

        # if evt['EventName'] == 's3:ObjectCreated:Put':
        #     bucket = evt['Records'][0]['s3']['bucket']['name']
        #     key = evt['Records'][0]['s3']['object']['key']
        #     self._key = key
        #     client.download_file(bucket, key, '/tmp/' + key)
        #     logging.info('Downloaded file')
        #     request = image_transform('/tmp/' + key)
        #     logging.info('Tranformed image')
        #     return {"instances": [request]}
        #
        #     img_data = image_transform('/tmp/' + key)
        #     img_input = np.asarray([img_data])
        #     tensor = np.float32(img_input)
        #
        #     infer_input = InferInput(name="predict", datatype='FP32', shape=tensor.shape)
        #     infer_input.set_data_from_numpy(tensor, False)
        #     infer_request = InferRequest(model_name=self.model_name, infer_inputs=[infer_input])
        #
        #     return infer_request
        #
        # raise Exception("unknown event")

    def postprocess(self, response: Union[Dict, InferResponse, ModelInferResponse], headers: Dict[str, str] = None) \
            -> Union[Dict, ModelInferResponse]:
        logging.info("response: %s", response)
        index = response["predictions"][0]["classes"]
        logging.info("digit:" + str(index))
        upload_path = f'digit-{index}/{self._key}'
        client.upload_file('/tmp/' + self._key, digits_bucket, upload_path)
        logging.info(f"Image {self._key} successfully uploaded to {upload_path}")
        return response

# #
# # Licensed under the Apache License, Version 2.0 (the "License");
# # you may not use this file except in compliance with the License.
# # You may obtain a copy of the License at
# #
# #    http://www.apache.org/licenses/LICENSE-2.0
# #
# # Unless required by applicable law or agreed to in writing, software
# # distributed under the License is distributed on an "AS IS" BASIS,
# # WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# # See the License for the specific language governing permissions and
# # limitations under the License.
#
# from typing import Dict, Union
# import logging
# import boto3
# import cv2
# import base64
# import json
# import numpy as np
#
# from cloudevents.http import CloudEvent
# from cloudevents.conversion import to_json
#
# import kserve
# from kserve import InferRequest, InferResponse, InferInput
# from kserve.protocol.grpc.grpc_predict_v2_pb2 import ModelInferResponse
#
# logging.basicConfig(level=kserve.constants.KSERVE_LOGLEVEL)
#
# session = boto3.Session()
# client = session.client('s3', endpoint_url='http://minio-service:9000', aws_access_key_id='minio',
#                         aws_secret_access_key='minio123')
# digits_bucket = 'digits'
#
# def image_transform(image):
#     img = cv2.imread(image, cv2.IMREAD_GRAYSCALE)
#     g = cv2.resize(255 - img, (28, 28))
#     g = g.flatten() / 255.0
#     return g.tolist()
#
# class ImageTransformer(kserve.Model):
#     def __init__(self, name: str, predictor_host: str, protocol: str):
#         super().__init__(name)
#         self.predictor_host = predictor_host
#         self._key = None
#         self.protocol = protocol
#         self.model_name = name
#
#     def preprocess(self, inputs: Union[Dict, CloudEvent, InferRequest],
#                          headers: Dict[str, str] = None) -> Union[Dict, InferRequest]:
#         logging.info("Received inputs %s", inputs)
#         cloud_event = inputs.get_data()
#         evt = json.loads(cloud_event)
#         logging.info("Received event %s", evt)
#
#         if evt['EventName'] == 's3:ObjectCreated:Put':
#             bucket = evt['Records'][0]['s3']['bucket']['name']
#             key = evt['Records'][0]['s3']['object']['key']
#             self._key = key
#
#             logging.info('Event for bucket=' + bucket + "; key=" + key)
#             client.download_file(bucket, key, '/tmp/' + key)
#             logging.info('Downloaded file')
#
#             request = image_transform('/tmp/' + key)
#             return {"instances": [request]}
#
#         raise Exception("unknown event")
#
#     def preprocess_2(self, inputs: Union[Dict, CloudEvent, InferRequest],
#                    headers: Dict[str, str] = None) -> Union[Dict, InferRequest]:
#         cloud_event = inputs.get_data()
#         evt = json.loads(cloud_event)
#
#         if evt['EventName'] == 's3:ObjectCreated:Put':
#             bucket = evt['Records'][0]['s3']['bucket']['name']
#             key = evt['Records'][0]['s3']['object']['key']
#             self._key = key
#
#             logging.info('Even for bucket=' + bucket + "; key=" + key)
#             client.download_file(bucket, key, '/tmp/' + key)
#
#             img_data = image_transform('/tmp/' + key)
#             logging.info('Image data' + img_data.__repr__())
#             img_input = np.asarray([img_data])
#             tensor = np.float32(img_input)
#
#             infer_input = InferInput(name="predict", datatype='FP32', shape=tensor.shape)
#             infer_input.set_data_from_numpy(tensor, False)
#             infer_request = InferRequest(model_name=self.model_name, infer_inputs=[infer_input])
#
#             return infer_request
#
#         raise Exception("unknown event")
#
#     def postprocess(self, response: Union[Dict, InferResponse, ModelInferResponse], headers: Dict[str, str] = None) \
#             -> Union[Dict, ModelInferResponse]:
#         logging.info("response: %s", response)
#         index = response["predictions"][0]["classes"]
#         logging.info("digit:" + str(index))
#         upload_path = f'digit-{index}/{self._key}'
#         client.upload_file('/tmp/' + self._key, digits_bucket, upload_path)
#         logging.info(f"Image {self._key} successfully uploaded to {upload_path}")
#         return response
#
#     def postprocess_2(self, response: Union[Dict, InferResponse, ModelInferResponse], headers: Dict[str, str] = None) \
#             -> Union[Dict, ModelInferResponse]:
#         print(headers)
#         infer_response = InferResponse.from_grpc(response)
#         index = infer_response.outputs[0].data[0]
#         logging.info("file: " + self._key + " infer result is digit: " + str(index))
#         client.upload_file('/tmp/' + self._key, 'digit-' + str(index), self._key)
#
#         return {"prediction": str(index)}
