import numpy as np
import coremltools as ct
import tensorflow as tf

from transformers import DistilBertTokenizer, TFDistilBertForMaskedLM


tokenizer = DistilBertTokenizer.from_pretrained('distilbert/distilbert-base-uncased')
distilbert_model = TFDistilBertForMaskedLM.from_pretrained('distilbert/distilbert-base-uncased')


max_seq_length = 128
input_shape = (1, max_seq_length) #(batch_size, maximum_sequence_length)

input_layer = tf.keras.layers.Input(shape=input_shape[1:], dtype=tf.int32, name='input')

prediction_model = distilbert_model(input_layer)
tf_model = tf.keras.models.Model(inputs=input_layer, outputs=prediction_model)

mlmodel = ct.convert(tf_model)

# Fill the input with zeros to adhere to input_shape
input_values = np.zeros(input_shape)
# Store the tokens from our sample sentence into the input
input_values[0,:8] = np.array(tokenizer.encode("Hello, my dog is cute")).astype(np.int32)

mlmodel.predict({'input':input_values}) # 'input' is the name of our input layer from (3)