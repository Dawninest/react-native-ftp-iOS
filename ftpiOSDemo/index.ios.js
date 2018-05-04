/**
 * Sample React Native App
 * https://github.com/facebook/react-native
 * @flow
 */

import React, { Component } from 'react';
import {
  AppRegistry,
  StyleSheet,
  Text,
  View,
  NativeModules,//使用自定义插件需要引入 NativeModules
  NativeEventEmitter,//使用自定义插件监听功能需要引入 NativeEventEmitter
} from 'react-native';

// 文件传输完成的监听
const Emitter = new NativeEventEmitter(NativeModules.FileTransfer);


export default class ftpiOSDemo extends Component {

  
  componentDidMount(){
      // 文件传输完成
      Emitter.addListener('completed', (completedFileInfoObj) => {
          const transferId = completedFileInfoObj.transferId;
          const isUpload = completedFileInfoObj.isUpload;
          const toAccount = completedFileInfoObj.toAccount;
          //通过传输任务ID及相关参数判断完成的任务
      });
      // 文件传输异常
      Emitter.addListener('fileTransfer', (errorInfoObj) => {
          //通过传输任务ID及相关参数判断完成的任务
      });
      // 文件传输的进度跟踪
      Emitter.addListener('updateProgress', (progressInfoObj) => {
          // 会不停地触发来更新进度 ，通过 transferId 来确认进度属于哪个任务
          const transferId = progressInfoObj.transferId;
          const percent = progressInfoObj.percent;
      });
  }


  download(){
    const ftpTask = {
        ftpServerIp: '10.131.129.40', //链接的FTP服务器IP
        username: 'admin', //登录FTP服务器的账户
        password: 'admin', //登录FTP服务器的密码
        ftpServerPort: 990, //FTP服务器端口
        fileMimeType: 'other', // other image audio 三种类型选一个
        isUpload: false, //上传 - true 下载 - false
        localPath: 'file:///xxx',//(绝对路径) file:///开头
        remoteFilePath: '/', //(绝对路径) ，上传时提供文件夹地址，后带 "/" eg /2016-11-11-1/，下载时提供文件地址(2016-11-11-1/down)
        toAccount: '文件发送对象',// 与FTP传输无关，能在传输监听中拿到，方便后续逻辑处理
        transferId: '23333333xxx',// 与FTP传输无关，能在传输监听中拿到，方便后续逻辑处理
        fileSize: 233333, // 与FTP传输无关，能在传输监听中拿到，方便后续逻辑处理
        isSSL: false, // iOS不支持ssl ，无用参数，方便与安卓版统一接口
    };
    NativeModules.FileTransfer.addFtpTask(ftpTask)

  }



  render() {
    return (
      <View style={styles.container}>
        <Text style={styles.welcome} onPress={this.download.bind(this)}>
          下载示范
        </Text>
      </View>
    );
  }
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: '#F5FCFF',
  },
  welcome: {
    fontSize: 20,
    textAlign: 'center',
    margin: 10,
  },
});

AppRegistry.registerComponent('ftpiOSDemo', () => ftpiOSDemo);
