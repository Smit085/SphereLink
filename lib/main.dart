import 'package:spherelink/screens/PanoramicWithMarkers.dart';
import 'package:spherelink/utils/MarkerFormDialog.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Marker App',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: PanoramicWithMarkers(),
    );
  }
}

//
// class MyHomePage extends StatefulWidget {
//   MyHomePage({Key? key, required this.title}) : super(key: key);
//
//   final String title;
//
//   @override
//   _MyHomePageState createState() => _MyHomePageState();
// }
//
// class _MyHomePageState extends State<MyHomePage> {
//   void _showMarkerForm(BuildContext context) {
//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return MarkerFormDialog(
//           onSave: (data) => print('Data saved: $data'),
//           onCancel: () => Navigator.of(context).pop(),
//         );
//       },
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: Text(widget.title)),
//       body: Center(
//         child: ElevatedButton(
//           onPressed: () => _showMarkerForm(context),
//           child: Text('Open Marker Form'),
//         ),
//       ),
//     );
//   }
// }
