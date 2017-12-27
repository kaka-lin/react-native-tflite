import React, { Component } from 'react';
import { requireNativeComponent, View } from 'react-native';

var RNTFLite = requireNativeComponent('RNTFLite', RNTFLiteView)

export default class RNTFLiteView extends Component {
  render() {
    return (
      <RNTFLite style={{flex: 1}}/>
    );
  }
}

export { RNTFLiteView };
