import 'dart:convert';
import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:sdp_transform/sdp_transform.dart';

class VideoCallViewModel extends ChangeNotifier {
  bool _offer = false;
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  RTCVideoRenderer localRenderer = new RTCVideoRenderer();
  RTCVideoRenderer remoteRenderer = new RTCVideoRenderer();

  FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? meetingId;

  

  Future initRenderers() async {
    await localRenderer.initialize();
    await remoteRenderer.initialize();
  }

  Future createpeerConnection() async {
    Map<String, dynamic> configuration = {
      "iceServers": [
        {'url': 'stun:stun.l.google.com:19302'},
      ]
    };

    final Map<String, dynamic> offerSdpConstraints = {
      "mandatory": {
        "OfferToReceiveAudio": true,
        "OfferToReceiveVideo": true,
      },
      "optional": [],
    };

    _localStream = await _getUserMedia();
    notifyListeners();

    RTCPeerConnection pc =
        await createPeerConnection(configuration, offerSdpConstraints);

    pc.addStream(_localStream!);

    pc.onIceCandidate = (e) async {
      if (e.candidate != null) {
        print(json.encode({
          'candidate': e.candidate.toString(),
          'sdpMid': e.sdpMid.toString(),
          'sdpMlineIndex': e.sdpMlineIndex,
        }));
        if (meetingId != null) {
          if (_offer)
            await _firestore.collection('meetings').doc(meetingId).update({
              'offerICE': FieldValue.arrayUnion([
                json.encode({
                  'candidate': e.candidate.toString(),
                  'sdpMid': e.sdpMid.toString(),
                  'sdpMlineIndex': e.sdpMlineIndex,
                })
              ])
            });
          else
            await _firestore.collection('meetings').doc(meetingId).update({
              'answerICE': FieldValue.arrayUnion([
                json.encode({
                  'candidate': e.candidate.toString(),
                  'sdpMid': e.sdpMid.toString(),
                  'sdpMlineIndex': e.sdpMlineIndex,
                })
              ])
            });
        }
      }
    };

    pc.onIceConnectionState = (e) {
      print(e);
    };

    pc.onAddStream = (stream) {
      print('addStream: ' + stream.id);
      remoteRenderer.srcObject = stream;
      notifyListeners();
    };

    _peerConnection = pc;
    notifyListeners();
  }

  _getUserMedia() async {
    final Map<String, dynamic> constraints = {
      'audio': false,
      'video': {
        'facingModel': 'user',
      }
    };

    MediaStream mediaStream =
        await navigator.mediaDevices.getUserMedia(constraints);
    localRenderer.srcObject = mediaStream;

    return mediaStream;
  }

  void createOffer() async {
    RTCSessionDescription description =
        await _peerConnection!.createOffer({'offerToReceiveVideo': 1});
    var session = parse(description.sdp.toString());
    log(json.encode(session));
    _offer = true;
    DocumentReference docRef = _firestore.collection('meetings').doc();

    await docRef.set({'meeting_id': docRef.id, 'offer': json.encode(session)});
    meetingId = docRef.id;

    print('meeting id ${docRef.id}');

    docRef.snapshots().listen((doc) async {
      if (doc.exists) {
        print('meeting doc update ${doc.data()}');
        dynamic dataJSON = doc.data();
        if (dataJSON?['answer'] != null) {
          var offerString = dataJSON?['answer'];
          await _setRemoteDescription(offerString);
        }
      }
    });

    _peerConnection!.setLocalDescription(description);
  }

  void createAnswer(String docId) async {
    DocumentReference docRef = _firestore.collection('meetings').doc(docId);
    DocumentSnapshot<dynamic> snapshot = await docRef.get();
    Map<String, dynamic>? dataJSON = snapshot.data();
    var offerString = dataJSON?['offer'];
    await _setRemoteDescription(offerString);
    meetingId = docId;

    RTCSessionDescription description =
        await _peerConnection!.createAnswer({'offerToReceiveVideo': 1});

    var session = parse(description.sdp.toString());
    log(json.encode(session));

    await _peerConnection!.setLocalDescription(description);

    await docRef.update({'answer': json.encode(session)});
    addCandidate((dataJSON?['offerICE'] as List<dynamic>).first);
  }

  Future _setRemoteDescription(String jsonString) async {
    dynamic session = await jsonDecode('$jsonString');

    String sdp = write(session, null);

    // RTCSessionDescription description =
    //     new RTCSessionDescription(session['sdp'], session['type']);
    RTCSessionDescription description =
        new RTCSessionDescription(sdp, _offer ? 'answer' : 'offer');
    print(description.toMap());

    await _peerConnection!.setRemoteDescription(description);
    return;
  }

  void addCandidate(String jsonString) async {
    dynamic session = await jsonDecode('$jsonString');
    print(session['candidate']);
    dynamic candidate = new RTCIceCandidate(
        session['candidate'], session['sdpMid'], session['sdpMlineIndex']);
    await _peerConnection!.addCandidate(candidate);
    notifyListeners();
  }

  @override
  void dispose() {
    localRenderer.dispose();
    remoteRenderer.dispose();
    super.dispose();
  }
}
