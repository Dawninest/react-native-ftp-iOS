package com.san.coap.modules.file;

import android.text.TextUtils;
import android.util.Log;
import com.facebook.react.bridge.*;
import com.facebook.react.modules.core.DeviceEventManagerModule;
import it.sauronsoftware.ftp4j.*;

import javax.net.ssl.SSLContext;
import javax.net.ssl.SSLSocketFactory;
import javax.net.ssl.TrustManager;
import javax.net.ssl.X509TrustManager;
import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.security.KeyManagementException;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.security.cert.X509Certificate;
import java.util.Queue;
import java.util.concurrent.ConcurrentLinkedQueue;
import java.util.HashMap;
import java.util.Map;

/**
 * FTP文件传输.
 * Created by dengd on 2017/9/18.
 */
public class FileTransferModule extends ReactContextBaseJavaModule {
    private static final String TAG = "FileTransferModule";
    /**
     * 上传文件线程
     */
    private TransferThread uploadFileThread;

    /**
     * 下载文件线程
     */
    private TransferThread downloadFileThread;

    /**
     * 上传语音线程
     */
    private TransferThread uploadAudioThread;

    /**
     * 下载语音线程
     */
    private TransferThread downloadAudioThread;

    /**
     * 上传语音线程
     */
    private TransferThread uploadImageThread;

    /**
     * 下载语音线程
     */
    private TransferThread downloadImageThread;

    private enum Event {
        fileTransfer,
        updateProgress,
        cancelAllError,
        completed
    }

    private enum FileMimeType {
        image,
        audio,
        other
    }

    public FileTransferModule(final ReactApplicationContext reactContext) {
        super(reactContext);
    }

    @Override
    public String getName() {
        return "FileTransfer";
    }

    /**
     * 添加文件传输任务.
     *
     * @param fileInfo 文件对象
     * @param promise  Promise对象
     */
    @ReactMethod
    public void addFtpTask(ReadableMap fileInfo, Promise promise) {
        final Boolean isUpload = fileInfo.getBoolean("isUpload");
        final String fileType = fileInfo.getString("fileMimeType");
        final FtpTaskInfo ftpTaskInfo = new FtpTaskInfo(fileInfo);
        if (isUpload) {
            if (FileMimeType.audio.toString().equals(fileType)) {
                if (this.uploadAudioThread == null || !this.uploadAudioThread.isAlive()) {
                    this.uploadAudioThread = new TransferThread();
                    this.uploadAudioThread.add(ftpTaskInfo);
                    this.uploadAudioThread.start();
                } else {
                    this.uploadAudioThread.add(ftpTaskInfo);
                }
            } else if (FileMimeType.image.toString().equals(fileType)) {
                if (this.uploadImageThread == null || !this.uploadImageThread.isAlive()) {
                    this.uploadImageThread = new TransferThread();
                    this.uploadImageThread.add(ftpTaskInfo);
                    this.uploadImageThread.start();
                } else {
                    this.uploadImageThread.add(ftpTaskInfo);
                }
            } else {
                if (this.uploadFileThread == null || !this.uploadFileThread.isAlive()) {
                    this.uploadFileThread = new TransferThread();
                    this.uploadFileThread.add(ftpTaskInfo);
                    this.uploadFileThread.start();
                } else {
                    this.uploadFileThread.add(ftpTaskInfo);
                }
            }
        } else {
            if (FileMimeType.audio.toString().equals(fileType)) {
                if (this.downloadAudioThread == null || !this.downloadAudioThread.isAlive()) {
                    this.downloadAudioThread = new TransferThread();
                    this.downloadAudioThread.add(ftpTaskInfo);
                    this.downloadAudioThread.start();
                } else {
                    this.downloadAudioThread.add(ftpTaskInfo);
                }
            } else if (FileMimeType.image.toString().equals(fileType)) {
                if (this.downloadImageThread == null || !this.downloadImageThread.isAlive()) {
                    this.downloadImageThread = new TransferThread();
                    this.downloadImageThread.add(ftpTaskInfo);
                    this.downloadImageThread.start();
                } else {
                    this.downloadImageThread.add(ftpTaskInfo);
                }
            } else if (FileMimeType.other.toString().equals(fileType)) {
                if (this.downloadFileThread == null || !this.downloadFileThread.isAlive()) {
                    this.downloadFileThread = new TransferThread();
                    this.downloadFileThread.add(ftpTaskInfo);
                    this.downloadFileThread.start();
                } else {
                    this.downloadFileThread.add(ftpTaskInfo);
                }
            }
        }
        promise.resolve("success");
    }

    /**
     * 取消文件传输任务.
     *
     * @param fileInfo 文件传输对象.
     * @param promise  Promise对象
     */
    @ReactMethod
    public void cancelFtpTask(ReadableMap fileInfo, Promise promise) {
        final String transferId = fileInfo.getString("transferId");
        final String fileType = fileInfo.getString("fileMimeType");
        final Boolean isUpload = fileInfo.getBoolean("isUpload");
        if (isUpload) {
            if (FileMimeType.audio.toString().equals(fileType)) {
                if (this.uploadAudioThread != null) {
                    this.uploadAudioThread.cancel(transferId);
                }
            } else if (FileMimeType.image.toString().equals(fileType)) {
                if (this.uploadImageThread != null) {
                    this.uploadImageThread.cancel(transferId);
                }
            } else if (FileMimeType.other.toString().equals(fileType) && this.uploadFileThread != null) {
                this.uploadFileThread.cancel(transferId);
            }
        } else {
            if (FileMimeType.audio.toString().equals(fileType)) {
                if (this.downloadAudioThread != null) {
                    this.downloadAudioThread.cancel(transferId);
                }
            } else if (FileMimeType.image.toString().equals(fileType)) {
                if (this.downloadImageThread != null) {
                    this.downloadImageThread.cancel(transferId);
                }
            } else if (FileMimeType.other.toString().equals(fileType) && this.downloadFileThread != null) {
                this.downloadFileThread.cancel(transferId);
            }
        }
        promise.resolve("success");
    }

    /**
     * 取消所有文件传输.
     *
     * @param promise Promise对象
     */
    @ReactMethod
    public void cacelAllFtpTask(Promise promise) {
        String faildTransferId = this.uploadFileThread.cancelAll();
        if (!TextUtils.isEmpty(faildTransferId)) {
            final WritableMap params = Arguments.createMap();
            params.putString("transferId", faildTransferId);
            this.sendEventToJS(params, Event.cancelAllError);
        }
        faildTransferId = this.uploadImageThread.cancelAll();
        if (!TextUtils.isEmpty(faildTransferId)) {
            final WritableMap params = Arguments.createMap();
            params.putString("transferId", faildTransferId);
            this.sendEventToJS(params, Event.cancelAllError);
        }
        faildTransferId = this.uploadAudioThread.cancelAll();
        if (!TextUtils.isEmpty(faildTransferId)) {
            final WritableMap params = Arguments.createMap();
            params.putString("transferId", faildTransferId);
            this.sendEventToJS(params, Event.cancelAllError);
        }
        faildTransferId = this.downloadFileThread.cancelAll();
        if (!TextUtils.isEmpty(faildTransferId)) {
            final WritableMap params = Arguments.createMap();
            params.putString("transferId", faildTransferId);
            this.sendEventToJS(params, Event.cancelAllError);
        }
        faildTransferId = this.downloadImageThread.cancelAll();
        if (!TextUtils.isEmpty(faildTransferId)) {
            final WritableMap params = Arguments.createMap();
            params.putString("transferId", faildTransferId);
            this.sendEventToJS(params, Event.cancelAllError);
        }
        faildTransferId = this.downloadAudioThread.cancelAll();
        if (!TextUtils.isEmpty(faildTransferId)) {
            final WritableMap params = Arguments.createMap();
            params.putString("transferId", faildTransferId);
            this.sendEventToJS(params, Event.cancelAllError);
        }
        promise.resolve("success");
    }


    /**
     * 向javascript端发送事件.
     *
     * @param params 参数.
     */
    private void sendEventToJS(WritableMap params, Event event) {
        this.getReactApplicationContext().
                getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter.class).
                emit(event.toString(), params);
    }

    /**
     * 出现异常时的处理.
     *
     * @param transferId 文件传输ID
     * @param message    消息内容
     */
    private void onException(final String transferId, final String message) {
        final WritableMap params = Arguments.createMap();
        params.putString("transferId", transferId);
        params.putString("error", message);
        this.sendEventToJS(params, Event.fileTransfer);
    }

    /**
     * 文件传输线程.
     */
    final class TransferThread extends Thread {
        /**
         * transferQueue
         */
        private final Queue<FtpTaskInfo> transferQueue = new ConcurrentLinkedQueue<FtpTaskInfo>();
        /**
         * ftpClient
         */
        private FTPClient ftpClient;
        /**
         * currentTransFileInfo
         */
        private FtpTaskInfo currentTransFileInfo;

        /**
         * run
         */
        @Override
        public void run() {
            while (true) {
                final FtpTaskInfo ftpTaskInfo = this.transferQueue.poll();
                if (ftpTaskInfo == null) {
                    return;// 当队列中不存在待上传文件时，中止线程
                }
                this.currentTransFileInfo = ftpTaskInfo;
                String transferId = null;
                try {
                    final ReadableMap fileInfo = ftpTaskInfo.getFileInfo();
                    transferId = fileInfo.getString("transferId");
                    if (this.ftpClient == null || !this.ftpClient.isConnected()) {
                        this.ftpClient = this.getFtpConnection(fileInfo);
                    }
                    if (this.ftpClient == null) {
                        FileTransferModule.this.onException(transferId, "连接文件服务器失败");
                    } else {
                        final String remoteFilePath = fileInfo.getString("remoteFilePath");
                        String localFilePath = fileInfo.getString("localPath");
                        if (localFilePath.startsWith("file://")) {
                            localFilePath = localFilePath.substring(7);
                        }
                        final long fileSize = fileInfo.getInt("fileSize");
                        if (fileInfo.getBoolean("isUpload")) {
                            this.upLoadFile(remoteFilePath, transferId, localFilePath, fileSize, this.ftpClient);
                        } else {
                            this.downLoadFile(remoteFilePath, transferId, localFilePath, fileSize, this.ftpClient);
                        }
                        WritableMap writableMap = Arguments.createMap();
                        writableMap.putBoolean("isUpload", fileInfo.getBoolean("isUpload"));
                        writableMap.putString("transferId", transferId);
                        FileTransferModule.this.sendEventToJS(writableMap, Event.completed);
                    }
                } catch (final IOException exception) {
                    FileTransferModule.this.onException(transferId, exception.getMessage());
                    Log.e(TAG, exception.getMessage(), exception);
                } catch (final FTPIllegalReplyException exception) {
                    FileTransferModule.this.onException(transferId, exception.getMessage());
                    Log.e(TAG, exception.getMessage(), exception);
                } catch (final FTPException exception) {
                    FileTransferModule.this.onException(transferId, exception.getMessage());
                    Log.e(TAG, exception.getMessage(), exception);
                } catch (final FTPDataTransferException exception) {
                    FileTransferModule.this.onException(transferId, exception.getMessage());
                    Log.e(TAG, exception.getMessage(), exception);
                } catch (final FTPAbortedException exception) {
                    FileTransferModule.this.onException(transferId, exception.getMessage());
                    Log.e(TAG, exception.getMessage(), exception);
                } catch (final Exception e){
                    FileTransferModule.this.onException(transferId, e.getMessage());
                    Log.e(TAG, e.getMessage(), e);
                }
            }
        }

        /**
         * 上传单个文件.
         *
         * @param ftpClient
         * @throws FTPException
         * @throws FTPIllegalReplyException
         * @throws IOException
         * @throws FTPAbortedException
         * @throws FTPDataTransferException
         */
        private void upLoadFile(final String remoteFilePath, final String transferId, final String localFilePath, final long fileSize, final FTPClient ftpClient) throws IOException, FTPIllegalReplyException, FTPException, FTPDataTransferException, FTPAbortedException {
            if (ftpClient.isConnected()) {
                /*********** 进入要传输到的目录 ****************/
                this.createAndEnterRemoteDir(remoteFilePath, ftpClient);
                final long startAt = this.getFileSize(transferId, ftpClient);
                FileInputStream inputStream = null;
                try {
                    final FtpTransferListener listener = new FtpTransferListener(fileSize, transferId);
                    listener.transferred((int) startAt);// 解决断点续传，进度更新问题.
                    inputStream = new FileInputStream(new File(localFilePath));
                    ftpClient.upload(transferId, inputStream, startAt, startAt, listener);
                } finally {
                    if (inputStream != null) {
                        inputStream.close();
                    }
                }
            }
        }

        /**
         * 创建并进行指定目录 ，如果存在则不创建.
         *
         * @throws FTPException
         * @throws FTPIllegalReplyException
         * @throws IOException
         */
        private void createAndEnterRemoteDir(final String dirPath, final FTPClient ftpClient) throws IOException, FTPIllegalReplyException, FTPException {
            /**************** 如果当前与所创建目录相同，则直接成功 *********************/
            final String ftpPath = ftpClient.currentDirectory();
            if (!dirPath.equals(ftpPath)) {
                final String[] tempDir = dirPath.split("/");
                ftpClient.changeDirectory("/");
                for (final String dirName : tempDir) {
                    try {
                        ftpClient.changeDirectory(dirName);
                    } catch (final IOException exception) {
                        ftpClient.createDirectory(dirName);
                        ftpClient.changeDirectory(dirName);
                        Log.w(TAG, exception.getMessage(), exception);
                    } catch (final FTPIllegalReplyException exception) {
                        ftpClient.createDirectory(dirName);
                        ftpClient.changeDirectory(dirName);
                        Log.w(TAG, exception.getMessage(), exception);
                    } catch (final FTPException exception) {
                        ftpClient.createDirectory(dirName);
                        ftpClient.changeDirectory(dirName);
                        Log.w(TAG, exception.getMessage(), exception);
                    }
                }
            }
        }

        /**
         * 获取文件在文件服务器上的大小.
         *
         * @param filePath
         * @param ftpClient
         * @return 文件大小
         */
        private long getFileSize(final String filePath, final FTPClient ftpClient) {
            long fileSize;
            try {
                fileSize = ftpClient.fileSize(filePath);
            } catch (final IOException exception) {
                fileSize = 0;
            } catch (final FTPIllegalReplyException exception) {
                fileSize = 0;
            } catch (final FTPException exception) {
                fileSize = 0;
            }
            return fileSize;
        }

        /**
         * 下载文件.
         *
         * @throws FTPException
         * @throws FTPIllegalReplyException
         * @throws IOException
         * @throws FTPAbortedException
         * @throws FTPDataTransferException
         */
        private void downLoadFile(final String remoteFilePath, final String transferId, final String localPath, final long fileSize,
                                  final FTPClient ftpClient) throws IOException, FTPIllegalReplyException, FTPException,
                FTPDataTransferException, FTPAbortedException {

            final int index = remoteFilePath.lastIndexOf('/');
            final String remotePath = remoteFilePath.substring(0, index);
            final String remoteFileName = remoteFilePath.substring(index + 1, remoteFilePath.length());
            if (!ftpClient.currentDirectory().equals(remotePath)) {
                ftpClient.changeDirectory("/" + remotePath);
            }
            /********** 开始下载文件 *********************/
            final FtpTransferListener listener = new FtpTransferListener(fileSize, transferId);
            final boolean isDownLoadSuccess = this.downLoad(ftpClient, remoteFileName, fileSize, localPath, listener);
            /******* 如果没有传输成功，则删除未完成的文件 ******************/
            if (!isDownLoadSuccess) {
                this.clearTmpFileOnDownLoadError(localPath);
            }
        }

        /**
         * 下载文件失败时删除临时文件.
         *
         * @param localPath
         * @throws Exception
         */
        private void clearTmpFileOnDownLoadError(final String localPath) {
            final File tmp = new File(localPath + ".sim");
            if (tmp.exists()) {
                tmp.delete();
            }
        }

        /**
         * 底层下载方法.
         *
         * @param receiveFileName
         * @param fileSize
         * @param localPath
         * @return boolean true if downLoad success.
         * @throws InterruptedException
         * @throws FTPException
         * @throws FTPIllegalReplyException
         * @throws IOException
         * @throws FTPAbortedException
         * @throws FTPDataTransferException
         */
        private boolean downLoad(final FTPClient ftpClient, final String receiveFileName, final long fileSize, final String localPath,
                                 final FTPDataTransferListener listener) throws IOException, FTPIllegalReplyException, FTPException, FTPDataTransferException, FTPAbortedException {
            // 本地文件
            final File localFile = new File(localPath);
//            final File tmpFile = new File(localPath + ".sim");
//            if (localFile.exists()) {
//                localFile.renameTo(tmpFile);
//            }
            if (!localFile.getParentFile().exists()) {
                localFile.getParentFile().mkdirs();
            }
            if (!this.checkFileExits(ftpClient, receiveFileName)) {
                if (listener != null) {
                    listener.failed();
                }
                return false;
            }
            long startAt = 0;
            int count = 1; // 尝试次数，如果连接30次没下载到数据则传输失败
            long oldSize = startAt; // 保存上一次传输完成时的数据大小
            boolean isDownLoadSuccess = false;
            try {
                while (true) {
                    if (count > 30) {
                        if (listener != null) {
                            listener.failed();
                        }
                        return false;
                    }
//                    ftpClient.download(receiveFileName, tmpFile, startAt, listener);
//                    startAt = tmpFile.length();
                    ftpClient.download(receiveFileName, localFile, startAt, listener);
                    startAt = localFile.length();
                    if (startAt == fileSize) {
                        // 传输完毕或者已经取消传输时
                        isDownLoadSuccess = true;
                        break;
                    }
                    if (startAt > oldSize) {
                        oldSize = startAt;
                        count = 1;
                    } else {
                        try {
                            Thread.sleep(1000);
                        } catch (final InterruptedException exception) {
                            Log.w(TAG, exception.getMessage(), exception);
                        }
                        count++;
                    }
                }
            } finally {
//                final File objectFile = new File(localPath);
//                if (objectFile.exists()) {
//                    objectFile.delete();
//                }
//                tmpFile.renameTo(objectFile);
            }
            return isDownLoadSuccess;
        }

        /**
         * 检查文件是否存在,超过30s不存在则抛异常，如果存在返回文件大小.
         *
         * @param ftpClient FTPClient
         * @param fileName  fileName
         * @return 文件大小
         * @throws FTPException
         * @throws FTPIllegalReplyException
         * @throws IOException
         * @throws InterruptedException
         */
        private boolean checkFileExits(final FTPClient ftpClient, final String fileName) {
            int tryCount = 0;
            while (true) {
                if (tryCount > 30) {
                    // 超时或其他异常
                    return false;
                }
                try {
                    ftpClient.fileSize(fileName);
                    return true;
                } catch (final IOException exception) {
                    Log.w(TAG, exception.getMessage(), exception);
                } catch (final FTPIllegalReplyException exception) {
                    Log.w(TAG, exception.getMessage(), exception);
                } catch (final FTPException exception) {
                    Log.w(TAG, exception.getMessage(), exception);
                }
                tryCount++;
                try {
                    Thread.sleep(1000);
                } catch (final InterruptedException exception) {
                    Log.w(TAG, exception.getMessage(), exception);
                }
            }
        }

        /**
         * 获取被动模式端口映射 map
         * @param filePassivePorts 如"55000:1234,55001:1235"
         */
        private Map<Integer,Integer> getPortMap(final String filePassivePorts) {
            // 数据连接端口映射关系<服务器真实端口，vpn外网端口>
            Map<Integer,Integer> portMap = null;
            if (filePassivePorts != null && !filePassivePorts.isEmpty()) {
                portMap = new HashMap<Integer, Integer>();
                String[] portArray = filePassivePorts.split(",");
                for (String port : portArray) {
                    String[] tempArray = port.split(":");
                    portMap.put(Integer.valueOf(tempArray[0]), Integer.valueOf(tempArray[1]));
                }
            }
            return portMap;
        }

        /**
         * 创建FTP连接.
         *
         * @param fileInfo 文件对象.
         * @return FTPClient
         */
        private FTPClient getFtpConnection(final ReadableMap fileInfo) {
            String ftpServerIp = fileInfo.getString("ftpServerIp");
            int ftpPort = fileInfo.getInt("ftpServerPort");
            String username = fileInfo.getString("username");
            String password = fileInfo.getString("password");
            Boolean isSSL = fileInfo.getBoolean("isSSL");
            // 默认重试次数
            int tryCount = 5;
            while (tryCount > 0) {
                try {
                    tryCount--;
                    // 使用SIMPFTPClient，以解决app上外网的端口与内网的端口不一致时文件传输失败的问题 lihe 2017/7/21
                    final String filePassivePorts = fileInfo.getString("filePassivePorts");
                    final FTPClient ftpClient = new SIMPFTPClient(this.getPortMap(filePassivePorts));
                    if (isSSL) {
                        // 初始化SSL套接字工厂类
                        final SSLContext sslContext = this.initSSLContext("TLS");
                        final SSLSocketFactory sslSocketFactory = sslContext.getSocketFactory();
                        ftpClient.setSSLSocketFactory(sslSocketFactory);
                        ftpClient.setSecurity(FTPClient.SECURITY_FTPES);
                        ftpClient.setType(FTPClient.TYPE_BINARY);
                    } else {
                        ftpClient.setType(FTPClient.TYPE_BINARY);
                    }
                    ftpClient.getConnector().setReadTimeout(30);
                    ftpClient.getConnector().setConnectionTimeout(30);
                    ftpClient.connect(ftpServerIp, ftpPort);
                    ftpClient.login(username, password);
                    return ftpClient;
                } catch (final IOException exception) {
                    Log.e(TAG, exception.getMessage(), exception);
                } catch (final FTPIllegalReplyException exception) {
                    Log.e(TAG, exception.getMessage(), exception);
                } catch (final FTPException exception) {
                    Log.e(TAG, exception.getMessage(), exception);
                }
            }
            return null;
        }

        /**
         * 初始化SSL上下文.
         *
         * @param sslVersion 协议版本 (SSL、TLS)
         * @return SSL上下文
         */
        private SSLContext initSSLContext(final String sslVersion) {
            final TrustManager[] trustManager = new TrustManager[]{new X509TrustManager() {
                /** getAcceptedIssuers */
                @Override
                public X509Certificate[] getAcceptedIssuers() {
                    return new X509Certificate[0];
                }

                /** checkClientTrusted */
                @Override
                public void checkClientTrusted(final X509Certificate[] certs, final String authType) {
                }

                /** checkServerTrusted */
                @Override
                public void checkServerTrusted(final X509Certificate[] certs, final String authType) {
                }
            }};
            SSLContext sslContext = null;
            try {
                sslContext = SSLContext.getInstance(sslVersion);
                sslContext.init(null, trustManager, new SecureRandom());
            } catch (final NoSuchAlgorithmException exception) {
                Log.e(TAG, exception.getMessage(), exception);
            } catch (final KeyManagementException exception) {
                Log.e(TAG, exception.getMessage(), exception);
            }
            return sslContext;
        }

        /**
         * add to transferQueue
         *
         * @param ftpTaskInfo ftpTaskInfo
         */
        public void add(final FtpTaskInfo ftpTaskInfo) {
            this.transferQueue.add(ftpTaskInfo);
        }

        /**
         * 取消某个文件传输
         *
         * @param transferId transferId
         */
        public void cancel(final String transferId) {
            if (this.currentTransFileInfo != null && this.ftpClient != null &&
                    transferId.equals(this.currentTransFileInfo.getFileInfo().getString("transferId"))) {
                try {
                    this.ftpClient.abortCurrentDataTransfer(true);
                } catch (final IOException exception) {
                    Log.e(TAG, exception.getMessage(), exception);
                } catch (final FTPIllegalReplyException exception) {
                    Log.e(TAG, exception.getMessage(), exception);
                }
            }
            for (final FtpTaskInfo ftpTaskInfo : this.transferQueue) {
                if (transferId.equals(ftpTaskInfo.getFileInfo().getString("transferId"))) {
                    this.transferQueue.remove(ftpTaskInfo);
                    return;
                }
            }
        }

        /**
         * 取消所有文件传输.
         */
        public String cancelAll() {
            for (final FtpTaskInfo ftpTaskInfo : this.transferQueue) {
                this.transferQueue.remove(ftpTaskInfo);
            }
            try {
                this.ftpClient.abortCurrentDataTransfer(true);
            } catch (final IOException exception) {
                Log.e(TAG, exception.getMessage(), exception);
                return this.currentTransFileInfo.getFileInfo().getString("transferId");
            } catch (final FTPIllegalReplyException exception) {
                Log.e(TAG, exception.getMessage(), exception);
                return this.currentTransFileInfo.getFileInfo().getString("transferId");
            }
            return "";
        }
    }


    /**
     * 文件传输任务信息.
     *
     * @author xzx
     */
    final class FtpTaskInfo {
        /**
         * 文件传输信息.
         */
        private final ReadableMap fileInfo;

        FtpTaskInfo(final ReadableMap fileInfo) {
            this.fileInfo = fileInfo;
        }

        ReadableMap getFileInfo() {
            return this.fileInfo;
        }
    }


    /**
     * 用于计算传输速度并通知上层的监听器.
     */
    final class FtpTransferListener implements FTPDataTransferListener {

        /**
         * 已经传输的的大小.
         */
        private long transferedSize;

        /**
         * 文件大小.
         */
        private final long fileSize;

        /**
         * transferId.
         */
        private final String transferId;

        FtpTransferListener(final long fileSize, final String transferId) {
            this.fileSize = fileSize;
            this.transferId = transferId;
        }

        /**
         * started.
         */
        @Override
        public void started() {
            if (this.transferedSize == 0) {
                final WritableMap params = Arguments.createMap();
                params.putDouble("percent", 0);
                params.putString("transferId", this.transferId);
                FileTransferModule.this.sendEventToJS(params, Event.updateProgress);
            }
        }

        /**
         * transferred.
         */
        @Override
        public void transferred(final int transfered) {
            this.transferedSize += transfered;
            if (this.transferedSize > 0) {
                final WritableMap params = Arguments.createMap();
                if (this.fileSize == 0) {
                    params.putDouble("percent", 0);
                } else {
                    final float percent = (float) this.transferedSize / this.fileSize;
                    params.putDouble("percent", percent);
                }
                params.putString("transferId", this.transferId);
                FileTransferModule.this.sendEventToJS(params, Event.updateProgress);
            }
        }

        /**
         * completed.
         */
        @Override
        public void completed() {
        }

        /**
         * aborted.
         */
        @Override
        public void aborted() {
            final WritableMap params = Arguments.createMap();
            params.putString("transferId", this.transferId);
            params.putString("error", "aborted");
            FileTransferModule.this.sendEventToJS(params, Event.fileTransfer);
        }

        /**
         * failed.
         */
        @Override
        public void failed() {
            final WritableMap params = Arguments.createMap();
            params.putString("error", "failed");
            params.putString("transferId", this.transferId);
            FileTransferModule.this.sendEventToJS(params, Event.fileTransfer);
        }
    }
}
