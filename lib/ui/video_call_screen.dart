import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:video_call_app/viewModels/video_call_view_model.dart';

class VideoCallScreen extends StatefulWidget {
  @override
  _VideoCallScreenState createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Consumer<VideoCallViewModel>(builder: (context, viewModel, child) {
        return Container(
          child: videoRenderers(viewModel),
        );
      }),
    );
  }

  SizedBox videoRenderers(VideoCallViewModel viewModel) => SizedBox(
          child: Stack(children: [
        Positioned(
          top: 0,
          bottom: 0,
          right: 0,
          left: 0,
          child: AspectRatio(
            aspectRatio: (viewModel.remoteRenderer.videoHeight /
                        viewModel.remoteRenderer.videoWidth >
                    0.0)
                ? viewModel.remoteRenderer.videoHeight /
                    viewModel.remoteRenderer.videoWidth
                : 9 / 16,
            child: Container(
                key: Key("remote"),
                child: RTCVideoView(
                  viewModel.remoteRenderer,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                )),
          ),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                  margin: EdgeInsets.only(right: 16),
                  height: 70 *
                      ((viewModel.localRenderer.videoWidth /
                                  viewModel.localRenderer.videoHeight >
                              0.0)
                          ? viewModel.localRenderer.videoWidth /
                              viewModel.localRenderer.videoHeight
                          : 16 / 9),
                  width: 70,
                  key: Key("local"),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: RTCVideoView(
                      viewModel.localRenderer,
                      objectFit:
                          RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                      mirror: true,
                    ),
                  )),
              Container(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Container(
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        padding: EdgeInsets.all(4),
                        child: IconButton(
                            onPressed: () {},
                            icon: Icon(
                              Icons.call_end,
                              color: Colors.white,
                            ))),
                    Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        padding: EdgeInsets.all(4),
                        child: IconButton(
                            onPressed: () {},
                            icon: Icon(
                              Icons.mic,
                            ))),
                    Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        padding: EdgeInsets.all(4),
                        child: IconButton(
                            onPressed: () {},
                            icon: Icon(
                              Icons.videocam,
                            ))),
                  ],
                ),
              )
            ],
          ),
        ),
      ]));

  @override
  void dispose() {
    super.dispose();
  }
}
