# react-native-tflite

Tensorflow Lite for React Native

Now: just suport for ios

# Getting started

## 1. Install

`$ npm install react-native-tflite -save`

## 2. Link

`$ react-native link react-native-tflite`

## 3. Use the Tensorflow Lite

Follow the documentation [here](https://github.com/tensorflow/tensorflow/blob/master/tensorflow/contrib/lite/g3doc/ios.md) to get integrate a TFLite model into your app.

## 4. Usage

```javascript
import { RNTFLiteView } from 'react-native-tflite';

class App extends Component {
  render() {
    return (
      <RNTFLiteView />
    );
  }
}
```

# Notice

Release mode need `ios 9.0` up

