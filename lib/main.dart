import 'dart:convert';
import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:sdp_transform/sdp_transform.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Video Call',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool _offer = false;
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  RTCVideoRenderer _localRenderer = new RTCVideoRenderer();
  RTCVideoRenderer _remoteRenderer = new RTCVideoRenderer();

  final sdpController = TextEditingController();

  FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? meetingId;

  @override
  void initState() {
    initRenderers();
    _createPeerConnection().then((pc) {
      _peerConnection = pc;
    });

    super.initState();
  }

  initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  _createPeerConnection() async {
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
    setState(() {});

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
      _remoteRenderer.srcObject = stream;
      setState(() {});
    };

    return pc;
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
    _localRenderer.srcObject = mediaStream;

    return mediaStream;
  }

  void _createOffer() async {
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

  void _createAnswer(String docId) async {
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
    _addCandidate((dataJSON?['offerICE'] as List<dynamic>).first);
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

  void _addCandidate(String jsonString) async {
    dynamic session = await jsonDecode('$jsonString');
    print(session['candidate']);
    dynamic candidate = new RTCIceCandidate(
        session['candidate'], session['sdpMid'], session['sdpMlineIndex']);
    await _peerConnection!.addCandidate(candidate);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Container(
        child: SingleChildScrollView(
          child: Column(
            children: [
              videoRenderers(),
              offerAndAnswerButtons(),
              sdpCandidatesTF(),
              ElevatedButton(
                  onPressed: () {
                    String text = sdpController.text;
                    _createAnswer(text);
                  },
                  child: Text('Join'))
            ],
          ),
        ),
      ),
    );
  }

  SizedBox videoRenderers() => SizedBox(
      height: 500,
      child: Stack(
        children: [
        AspectRatio(
          aspectRatio:(_remoteRenderer.videoHeight / _remoteRenderer.videoWidth > 0.0)?   _remoteRenderer.videoHeight / _remoteRenderer.videoWidth :9/16,
          child: Container(
            clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                 color: Colors.grey,
                  border: Border.all(color: Colors.white, width: 4),
                  borderRadius: BorderRadius.circular(16)),
           
              key: Key("remote"), child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: RTCVideoView(_remoteRenderer))),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          height:  70 * ( (_localRenderer.videoWidth / _localRenderer.videoHeight>0.0)? _localRenderer.videoWidth / _localRenderer.videoHeight:16/9),
          width: 70,
          child: Container(
              key: Key("local"),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 4),
                  borderRadius: BorderRadius.circular(16)),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: RTCVideoView(
                  _localRenderer,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  mirror: true,
                ),
              )),
        ),
      ]));

  Row offerAndAnswerButtons() => Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          ElevatedButton(onPressed: _createOffer, child: Text('Offer')),
          //ElevatedButton(onPressed: _createAnswer, child: Text('Answer')),
        ],
      );


  Widget sdpCandidatesTF() => Padding(
        padding: const EdgeInsets.all(8.0),
        child: TextField(
          decoration: InputDecoration(
              hintText: 'Enter meeting id', border: OutlineInputBorder()),
          controller: sdpController,
        ),
      );

  @override
  void dispose() {
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    sdpController.dispose();
    super.dispose();
  }
}
