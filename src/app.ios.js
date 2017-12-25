import { AppRegistry } from 'react-native';
import { StackNavigator, TabNavigator } from 'react-navigation';

import RNTFLite from './RNTFLite';

const MainHomeNavigator = TabNavigator({
  RNTFLite: {screen: RNTFLite},
});

MainHomeNavigator.navigationOptions = {
  title: 'Home'
};

const App = StackNavigator({
  Home: { screen: MainHomeNavigator},
  //Profile: { screen: ShowPhotos},
});

AppRegistry.registerComponent('RNTensorflowLite', () => App);
