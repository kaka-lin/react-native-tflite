# RNTFLiteExample

This is example of react-native-tflite


# Getting stared

## 1. Use react-native to creat app

```bash
react-native init YourProjectName
```

## 2. Install react-native-tflite & link

```bash
npm install react-native-tflite -save
react-native link react-native-tflite
```

## 3. install TensorFlow-experimental

```bash
cd ios
touch Podfile
```

- use any you like editor (ex: `vim`) to add followinf content:

```bash
    target 'YourProjectName'
       pod 'TensorFlow-experimental'
```

- Then you run `pod install` to download and install the TensorFlow-experimental pod


## 4. Build TensorFlow Lite for iOS

- Follow the documentation [here](https://github.com/tensorflow/tensorflow/blob/master/tensorflow/contrib/lite/g3doc/ios.md)

- `Open` YourProjectName.xcworkspace instead of YourProjectName.xcodeproj

- In your apps `Libraries folder` find `RNTFLite.xcodeproj`, then in "Build Settings" modify `Header Search Paths` and `Library Search Paths` to fit your `Tensorflow` path

- Add the library at `tensorflow/contrib/lite/gen/lib/libtensorflow-lite.a` to your linking build stage, and in Search Paths add `tensorflow/contrib/lite/gen/lib` to the Library Search Paths setting

## 5. Add model and label

- Add model and label to your app

## 6. Camera Privacy

- Don't forget add `Privacy - Camera Usage Description` to your app


## 7. Use react-native-tflite

- Now, you can use `react-native-tflite` in your react-native app

- Example:

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


