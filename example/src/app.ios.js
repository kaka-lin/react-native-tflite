import React, { Component } from 'react';
import { AppRegistry, View } from 'react-native';

import { RNTFLiteView } from 'react-native-tflite';

export default class App extends Component {
  render() {
    return (
      <RNTFLiteView />
    );
  }
}

AppRegistry.registerComponent('RNTFLiteExample', () => App);
