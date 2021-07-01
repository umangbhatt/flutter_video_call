import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_call_app/ui/join_call_screen.dart';
import 'package:video_call_app/ui/video_call_screen.dart';
import 'package:video_call_app/viewModels/video_call_view_model.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Flutter Video Call'),
      ),
      body: Center(
        child: Container(
          constraints: BoxConstraints(maxWidth: 500),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                  onPressed: () async {
                    await Provider.of<VideoCallViewModel>(context,
                            listen: false)
                        .initRenderers();
                    await Provider.of<VideoCallViewModel>(context,
                            listen: false)
                        .createpeerConnection();
                    Provider.of<VideoCallViewModel>(context, listen: false)
                        .createOffer();
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (context) => VideoCallScreen()));
                  },
                  child: Text('New Meeting')),
              ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (context) => JoinCallScreen()));
                  },
                  child: Text('Join Meeting')),
            ],
          ),
        ),
      ),
    );
  }
}
