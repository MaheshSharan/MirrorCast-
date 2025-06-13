import 'dart:async';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:android_app/models/connection_state.dart';
import 'package:android_app/services/screen_capture_service.dart';
import 'package:android_app/config/app_config.dart';

class WebRTCService {
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  final _screenCaptureService = ScreenCaptureService();
  final _connectionStateController = StreamController<ConnectionState>.broadcast();
  final _iceCandidatesController = StreamController<RTCIceCandidate>.broadcast();

  Stream<ConnectionState> get connectionState => _connectionStateController.stream;
  Stream<RTCIceCandidate> get iceCandidates => _iceCandidatesController.stream;
  Function(RTCTrackEvent)? onTrack;

  Future<void> initialize() async {    final configuration = {
      'iceServers': [
        {
          'urls': AppConfig.stunServers,
        }
      ],
      'sdpSemantics': 'unified-plan',
      'bundlePolicy': 'max-bundle',
      'rtcpMuxPolicy': 'require',
    };

    final constraints = {
      'mandatory': {
        'OfferToReceiveVideo': true,
        'OfferToReceiveAudio': false,
      },
      'optional': [
        {'DtlsSrtpKeyAgreement': true},
        {'RtpDataChannels': true},
      ],
    };

    _peerConnection = await createPeerConnection(configuration, constraints);

    _peerConnection?.onIceCandidate = (candidate) {
      _iceCandidatesController.add(candidate);
    };

    _peerConnection?.onConnectionState = (state) {
      _connectionStateController.add(ConnectionState.fromRTCState(state));
    };

    _peerConnection?.onIceConnectionState = (state) {
      _connectionStateController.add(ConnectionState.fromIceState(state));
    };

    _peerConnection?.onTrack = onTrack;
  }

  Future<void> startScreenCapture() async {
    if (_localStream != null) return;

    final stream = await _screenCaptureService.startScreenCapture();
    _localStream = stream;

    // Configure video encoding
    final videoTrack = stream.getVideoTracks().first;    // Configure video constraints using AppConfig
    await videoTrack.applyConstraints({
      'mandatory': {
        'minWidth': '${AppConfig.defaultWidth}',
        'minHeight': '${AppConfig.defaultHeight}',
        'minFrameRate': '30',
        'maxFrameRate': '${AppConfig.maxFramerate}',
      },
      'optional': [
        {'googLeakyBucket': true},
        {'googTemporalLayeredScreencast': true},
      ],
    });    // Set video encoding parameters using AppConfig
    final sender = _peerConnection?.getSenders().firstWhere(
          (sender) => sender.track?.kind == 'video',
        );
    if (sender != null) {
      final parameters = sender.parameters;
      if (parameters.encodings != null) {
        parameters.encodings![0].maxBitrate = AppConfig.maxBitrate;
        parameters.encodings![0].minBitrate = AppConfig.minBitrate;
        parameters.encodings![0].maxFramerate = AppConfig.maxFramerate;
        parameters.encodings![0].scaleResolutionDownBy = 1.0;
        await sender.setParameters(parameters);
      }
    }

    _peerConnection?.addStream(stream);
  }

  Future<void> stopScreenCapture() async {
    if (_localStream == null) return;

    _localStream?.getTracks().forEach((track) => track.stop());
    _peerConnection?.removeStream(_localStream!);
    _localStream = null;
    await _screenCaptureService.stopScreenCapture();
  }

  Future<RTCSessionDescription> createOffer() async {
    final offer = await _peerConnection!.createOffer({
      'offerToReceiveVideo': true,
      'offerToReceiveAudio': false,
    });

    // Set codec preferences
    final sdp = offer.sdp;
    final modifiedSdp = _setCodecPreferences(sdp);
    final modifiedOffer = RTCSessionDescription(modifiedSdp, 'offer');

    await _peerConnection!.setLocalDescription(modifiedOffer);
    return modifiedOffer;
  }

  Future<RTCSessionDescription> createAnswer() async {
    final answer = await _peerConnection!.createAnswer({
      'offerToReceiveVideo': true,
      'offerToReceiveAudio': false,
    });

    // Set codec preferences
    final sdp = answer.sdp;
    final modifiedSdp = _setCodecPreferences(sdp);
    final modifiedAnswer = RTCSessionDescription(modifiedSdp, 'answer');

    await _peerConnection!.setLocalDescription(modifiedAnswer);
    return modifiedAnswer;
  }

  String _setCodecPreferences(String sdp) {
    // Prefer H.264 over VP8/VP9 for better hardware acceleration
    final lines = sdp.split('\n');
    final videoSection = lines.indexWhere((line) => line.startsWith('m=video'));
    if (videoSection != -1) {
      final codecLine = lines.indexWhere(
        (line) => line.startsWith('a=rtpmap:') && line.contains('H264'),
        videoSection,
      );
      if (codecLine != -1) {
        final codecId = lines[codecLine].split(':')[1].split(' ')[0];
        lines.insert(videoSection + 1, 'a=fmtp:$codecId profile-level-id=42e01f;level-asymmetry-allowed=1');
      }
    }
    return lines.join('\n');
  }

  Future<void> setRemoteDescription(RTCSessionDescription description) async {
    await _peerConnection!.setRemoteDescription(description);
  }

  Future<void> addIceCandidate(RTCIceCandidate candidate) async {
    await _peerConnection!.addCandidate(candidate);
  }

  Future<void> close() async {
    await stopScreenCapture();
    await _peerConnection?.close();
    _peerConnection = null;
    await _connectionStateController.close();
    await _iceCandidatesController.close();
  }
} 