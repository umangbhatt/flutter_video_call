import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'package:video_call_app/ui/video_call_screen.dart';
import 'package:video_call_app/viewModels/video_call_view_model.dart';

class JoinCallScreen extends StatefulWidget {
  @override
  _JoinCallScreenState createState() => _JoinCallScreenState();
}

class _JoinCallScreenState extends State<JoinCallScreen> {
  final sdpController = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Join meeting'),
      ),
      body: Container(
        constraints: BoxConstraints(maxWidth: 500),
        child: Column(
          children: [
            sdpCandidatesTF(),
            ElevatedButton(
                onPressed: () async {
                  await Provider.of<VideoCallViewModel>(context, listen: false)
                      .initRenderers();
                  await Provider.of<VideoCallViewModel>(context, listen: false)
                      .createpeerConnection();

                  String meetingId = sdpController.text;
                  Provider.of<VideoCallViewModel>(context, listen: false)
                      .createAnswer(meetingId);

                  Navigator.of(context).pushReplacement(MaterialPageRoute(
                      builder: (context) => VideoCallScreen()));
                },
                child: Text('Join'))
          ],
        ),
      ),
    );
  }

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
    sdpController.dispose();
    super.dispose();
  }
}
