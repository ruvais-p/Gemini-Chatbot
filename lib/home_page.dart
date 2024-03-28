import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text_google_dialog/speech_to_text_google_dialog.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key}) : super(key: key);

  @override
  State<MyHomePage> createState() => _MyWidgetState();
}

class _MyWidgetState extends State<MyHomePage> {
  // Data
  XFile? pickedImage;
  String myText = '';
  bool scanning = false;
  bool speaking = false;
  // Controllers
  final TextEditingController prompt = TextEditingController();
  final ImagePicker imagePicker = ImagePicker();
  final FlutterTts flutterTts = FlutterTts();
  // Message list
  List<Map> messages = [];
  // Url and headers for image chat
  final String apiUrlVision =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-pro-vision:generateContent?key=YOUR_API_KEY';

  final Map<String, String> headers = {
    'Content-Type': 'application/json',
  };
  // Url and headers for text chat
  final String apiUrlText =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent?key=YOUR_API_KEY';

  // Functions

  void copyText(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied'),
      ),
    );
  }

  Future<void> speakText(String text) async {
    setState(() {
      speaking = true;
    });
    await flutterTts.setVolume(0.5);
    await flutterTts.setSpeechRate(0.5);
    await flutterTts.setPitch(1);
    await flutterTts.speak(text);
  }

  void stopSpeaking() async {
    await flutterTts.stop();
    setState(() {
      speaking = false;
    });
  }

  Future<void> getImage(ImageSource ourSource) async {
    try {
      final XFile? result = await imagePicker.pickImage(source: ourSource);
      if (result != null) {
        setState(() {
          pickedImage = result;
          messages.insert(0, {"data": 1, "messages": '', "image": pickedImage});
        });
      }
    } catch (e) {
      print('Error picking image: $e');
    }
  }

  Future<void> getImageChatData(XFile? image, String promptText) async {
    if (image == null || promptText == '') {
      return;
    }

    setState(() {
      scanning = true;
      myText = '';
    });

    try {
      List<int> imageBytes = await image.readAsBytes();
      String base64File = base64Encode(imageBytes);

      final data = {
        "contents": [
          {
            "parts": [
              {"text": promptText},
              {
                "inlineData": {
                  "mimeType": "image/jpeg",
                  "data": base64File,
                }
              }
            ]
          }
        ],
        "generationConfig": {
          "temperature": 1,
          "topK": 32,
          "topP": 1,
          "maxOutputTokens": 4096,
          "stopSequences": []
        },
        "safetySettings": [
          {
            "category": "HARM_CATEGORY_HARASSMENT",
            "threshold": "BLOCK_MEDIUM_AND_ABOVE"
          },
          {
            "category": "HARM_CATEGORY_HATE_SPEECH",
            "threshold": "BLOCK_MEDIUM_AND_ABOVE"
          },
          {
            "category": "HARM_CATEGORY_SEXUALLY_EXPLICIT",
            "threshold": "BLOCK_MEDIUM_AND_ABOVE"
          },
          {
            "category": "HARM_CATEGORY_DANGEROUS_CONTENT",
            "threshold": "BLOCK_MEDIUM_AND_ABOVE"
          }
        ]
      };

      final response = await http.post(
        Uri.parse(apiUrlVision),
        headers: headers,
        body: jsonEncode(data),
      );

      if (response.statusCode == 200) {
        var result = jsonDecode(response.body);
        myText = result['candidates'][0]['content']['parts'][0]['text'];
      } else {
        myText = 'Response status: ${response.statusCode}';
      }
    } catch (e) {
      print('Error processing image: $e');
      myText = 'Error: $e';
    }

    setState(() {
      scanning = false;
      messages.insert(0, {"data": 0, "messages": myText, "image": null});
    });
  }

  Future<void> getTextChatData(String prompt) async {
    if (prompt == '') {
      return;
    }
    setState(() {
      scanning = true;
      myText = '';
    });
    try {
      final data = {
        "contents": [
          {
            "role": "user",
            "parts": [
              {"text": prompt}
            ]
          }
        ],
        "generationConfig": {
          "temperature": 0.9,
          "topK": 1,
          "topP": 1,
          "maxOutputTokens": 2048,
          "stopSequences": []
        },
        "safetySettings": [
          {
            "category": "HARM_CATEGORY_HARASSMENT",
            "threshold": "BLOCK_MEDIUM_AND_ABOVE"
          },
          {
            "category": "HARM_CATEGORY_HATE_SPEECH",
            "threshold": "BLOCK_MEDIUM_AND_ABOVE"
          },
          {
            "category": "HARM_CATEGORY_SEXUALLY_EXPLICIT",
            "threshold": "BLOCK_MEDIUM_AND_ABOVE"
          },
          {
            "category": "HARM_CATEGORY_DANGEROUS_CONTENT",
            "threshold": "BLOCK_MEDIUM_AND_ABOVE"
          }
        ]
      };

      final response = await http.post(
        Uri.parse(apiUrlText),
        headers: headers,
        body: jsonEncode(data),
      );

      if (response.statusCode == 200) {
        var result = jsonDecode(response.body);
        myText = result['candidates'][0]['content']['parts'][0]['text'];
      } else {
        myText = 'Response status: ${response.statusCode}';
      }
    } catch (e) {
      print('Error processing text: $e');
      myText = 'Error: $e';
    }

    setState(() {
      scanning = false;
      messages.insert(0, {"data": 0, "messages": myText, "image": null});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Gemini Bot",
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color.fromRGBO(63, 159, 127, 1),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(
              Icons.attach_file_sharp,
              color: Colors.white,
              size: 25,
            ),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(5),
        child: Column(
          children: [
            Flexible(
              child: ListView.builder(
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (context, index) => chat(
                      messages[index]["messages"].toString(),
                      messages[index]["data"],
                      messages[index]["image"])),
            ),
            const SizedBox(height: 5),
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Expanded(
                  child: TextField(
                    controller: prompt,
                    cursorColor: Colors.black87,
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 20,
                    ),
                    decoration: InputDecoration(
                      hintText: "Message...",
                      hintStyle: TextStyle(
                        color: Colors.black38,
                        fontSize: 20,
                      ),
                      enabled: true,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(70),
                        borderSide: const BorderSide(
                          color: Colors.black,
                          width: 2,
                        ),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(70),
                        borderSide: BorderSide(
                          color: Colors.black,
                          width: 2,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(70),
                        borderSide: BorderSide(
                          color: Colors.black,
                          width: 2,
                        ),
                      ),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: () => getImage(ImageSource.gallery),
                            icon: const Icon(
                              Icons.image,
                              color: Colors.black,
                            ),
                          ),
                          IconButton(
                            onPressed: () => getImage(ImageSource.camera),
                            icon: const Icon(
                              Icons.camera_alt_outlined,
                              color: Colors.black,
                            ),
                          )
                        ],
                      ),
                      prefixIcon: IconButton(
                        onPressed: () async {
                          bool isServiceAvailable =
                              await SpeechToTextGoogleDialog.getInstance()
                                  .showGoogleDialog(onTextReceived: (data) {
                            setState(() {
                              prompt.text = data.toString();
                            });
                          });
                        },
                        icon: const Icon(
                          Icons.mic,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(
                  width: 2,
                ),
                InkWell(
                  onTap: () {
                    if (speaking == false) {
                      if (pickedImage == null) {
                        getTextChatData(prompt.text);
                        setState(() {
                          if (prompt.text != '') {
                            messages.insert(0, {
                              "data": 1,
                              "messages": prompt.text,
                            });
                          }
                        });
                        prompt.clear();
                      } else {
                        getImageChatData(pickedImage, prompt.text);
                        setState(() {
                          if (prompt.text != '') {
                            messages.insert(0, {
                              "data": 1,
                              "messages": prompt.text,
                              "image": null
                            });
                          }
                        });
                        prompt.clear();
                      }
                    } else {
                      stopSpeaking();
                    }
                  },
                  child: speaking == false
                      ? CircleAvatar(
                          radius: 30,
                          backgroundColor: Color.fromRGBO(63, 159, 127, 1),
                          child: Container(
                            child: scanning == false
                                ? Icon(
                                    Icons.arrow_upward,
                                    color: Colors.white,
                                    size: 40,
                                  )
                                : SpinKitRipple(
                                    color: Colors.white,
                                  ),
                          ),
                        )
                      : CircleAvatar(
                          backgroundColor: Color.fromRGBO(63, 159, 127, 1),
                          radius: 30,
                          child: SpinKitWave(
                            itemCount: 4,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget chat(String message, int data, XFile? image) {
    return Container(
      padding: EdgeInsets.only(left: 5, right: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (image != null)
            Container(
              height: 340,
              child: Center(
                child: Image.file(
                  File(image.path),
                  height: 400,
                ),
              ),
            ),
          if (message != '')
            Row(
              mainAxisAlignment:
                  data == 1 ? MainAxisAlignment.end : MainAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.all(5),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      color: data == 0
                          ? Color.fromARGB(255, 255, 255, 255)
                          : Color.fromRGBO(63, 159, 127, 1),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(10),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 3,
                          ),
                          Flexible(
                            child: Container(
                              constraints: data == 0
                                  ? BoxConstraints(
                                      maxWidth: 325,
                                      minWidth: 50,
                                    )
                                  : BoxConstraints(
                                      maxWidth: 325,
                                      minWidth: 50,
                                      minHeight: 25,
                                    ),
                              child: Column(
                                children: [
                                  if (data == 0)
                                    Row(
                                      children: [
                                        IconButton(
                                          onPressed: () {
                                            copyText(message);
                                          },
                                          icon: Icon(
                                            Icons.copy,
                                            color:
                                                Color.fromRGBO(63, 159, 127, 1),
                                          ),
                                        ),
                                        if (speaking == false)
                                          IconButton(
                                            onPressed: () {
                                              speakText(message);
                                            },
                                            icon: Icon(
                                              Icons.volume_up,
                                              color: Color.fromRGBO(
                                                  63, 159, 127, 1),
                                            ),
                                          )
                                        else
                                          IconButton(
                                            onPressed: () {
                                              stopSpeaking();
                                            },
                                            icon: Icon(
                                              Icons.stop_circle_outlined,
                                              color: Color.fromRGBO(
                                                  63, 159, 127, 1),
                                            ),
                                          ),
                                      ],
                                    )
                                  else
                                    Container(),
                                  Text(
                                    message,
                                    style: TextStyle(
                                      fontSize: 20,
                                      color: data == 0
                                          ? Colors.black
                                          : Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
