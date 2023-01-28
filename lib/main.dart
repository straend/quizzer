import 'dart:collection';

import 'package:flutter/material.dart';
import 'configure_nonweb.dart' if (dart.library.html) 'configure_web.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  configureApp();
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'På Spåret bootleg',
      theme: ThemeData(primarySwatch: Colors.orange),
      onGenerateRoute: (settings) {
        // Handle '/'
        if (settings.name == '/') {
          return MaterialPageRoute(
              builder: (context) => MyHomePage(title: 'På Spåret Quizzer'));
        }

        // Handle '/q/:id/:team'
        var uri = Uri.parse(settings.name);
        if (uri.pathSegments.length == 3 && uri.pathSegments.first == 'q') {
          var id = uri.pathSegments[1];
          var team = uri.pathSegments[2];
          return MaterialPageRoute(
              builder: (context) => new QuizzPage(id: id, team: team));
        }

        // Handle '/q/:id/'
        if (uri.pathSegments.length == 2 && uri.pathSegments.first == 'q') {
          var id = uri.pathSegments[1];
          return MaterialPageRoute(
              builder: (context) =>
                  new MyHomePage(title: 'På Spåret Quizzer', id: id));
        }
        // Handle '/control/:id/'
        if (uri.pathSegments.length == 2 &&
            uri.pathSegments.first == 'control') {
          var id = uri.pathSegments[1];
          return MaterialPageRoute(
              builder: (context) => new QuizzControlPage(id: id));
        }
        // Handle '/result/:id/'
        if (uri.pathSegments.length == 2 &&
            uri.pathSegments.first == 'result') {
          var id = uri.pathSegments[1];
          return MaterialPageRoute(
              builder: (context) => new QuizzResult(id: id));
        }

        return MaterialPageRoute(
            builder: (context) => MyHomePage(title: 'På Spåret Quizzer'));
      },
    );
  }
}

Iterable<E> mapIndexed<E, T>(
    Iterable<T> items, E Function(int index, T item) f) sync* {
  var index = 0;

  for (final item in items) {
    yield f(index, item);
    index = index + 1;
  }
}

Scaffold waitingScreen(String team) {
  return Scaffold(
      appBar: AppBar(
        title: Text("$team kör På Spåret"),
      ),
      body: Container(
          child: Center(
              child: Column(
        children: [
          loadingScreen(),
          Text("Waiting for Host"),
        ],
      ))));
}

Container loadingScreen() {
  return Container(
    alignment: Alignment.center,
    padding: EdgeInsets.only(top: 10.0),
    child: CircularProgressIndicator(
      strokeWidth: 2.0,
      valueColor: AlwaysStoppedAnimation(Colors.deepOrange),
    ),
  );
}

class QuizzResult extends StatefulWidget {
  final String id;
  QuizzResult({Key key, this.id}) : super(key: key);

  @override
  _QuizzResultState createState() => _QuizzResultState(id: id);
}

class _QuizzResultState extends State<QuizzResult> {
  final String id;
  String city;

  CollectionReference quizzes =
      FirebaseFirestore.instance.collection('quizzes');

  _QuizzResultState({this.id});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
        stream: quizzes.doc(this.id).snapshots(),
        builder:
            (BuildContext context, AsyncSnapshot<DocumentSnapshot> snapshot) {
          if (snapshot.hasError) {
            return Text('Something went wrong');
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return loadingScreen();
          }

          Map<String, dynamic> data = snapshot.data.data();
          final Map<String, dynamic> responses = data['responses'];
          int answers = 0;
          List<DataRow> answ = [];
          List<DataRow> answQ = [];
          List<DataColumn> headerGuesses = [];

          if (city != null) {
            for (var i = 0; i < data['cities'][city]['questions'].length; i++) {
              var q = data['cities'][city]['questions'][i];
              List<DataCell> list = [];
              list.add(DataCell(Text(q['question'])));
              list.add(DataCell(Text(q['answer'])));
              for (String team in responses.keys) {
                if (responses.containsKey(team) &&
                    responses[team].containsKey('quiz') &&
                    responses[team]['quiz'].containsKey(city) &&
                    responses[team]['quiz'][city].containsKey(q['question'])) {
                  list.add(DataCell(
                      Text(responses[team]['quiz'][city][q['question']])));
                } else {
                  list.add(DataCell(Text(' ')));
                }
              }
              answQ.add(DataRow(cells: list));
            }

            for (String team in responses.keys) {
              Map<String, dynamic> rsp = responses[team];
              if (rsp.containsKey(city)) {
                answers += 1;
                var x = rsp[city]
                    .map(
                      ((element) => DataRow(
                            cells: <DataCell>[
                              DataCell(Text(element['points'].toString())),
                              DataCell(Text(team)),
                              DataCell(Text(element['guess'])),
                            ],
                          )),
                    )
                    .toList();
                for (DataRow i in x) {
                  answ.add(i);
                }
              }
            }
            headerGuesses.add(DataColumn(label: Text("Question")));
            headerGuesses.add(DataColumn(label: Text("Correct")));

            for (String x in responses.keys) {
              headerGuesses.add(DataColumn(label: Text(x)));
            }
          }
          List<Widget> children = [];
          children.add(Row(children: [
            DropdownButton<String>(
              value: city,
              hint: Text("Select city"),
              onChanged: (value) {
                setState(() {
                  city = value;
                });
              },
              items: data['cities'].keys.map<DropdownMenuItem<String>>((k) {
                return DropdownMenuItem<String>(
                    value: k.toString(), child: Text(k.toString()));
              }).toList(),
            ),
            Text(answers.toString()),
          ]));

          if (city != null) {
            children.add(Row(children: [
              DataTable(columns: const <DataColumn>[
                DataColumn(label: Text('points')),
                DataColumn(label: Text('Team')),
                DataColumn(label: Text('Guess')),
              ], rows: answ),
            ]));
            children.add(Row(children: [
              DataTable(
                columns: headerGuesses,
                rows: answQ,
              )
            ]));
          }
          return Scaffold(
              appBar: AppBar(
                title: Text(id),
              ),
              body: Container(
                  padding: const EdgeInsets.all(32),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: Column(children: children),
                    ),
                  )));
        });
  }
}

class QuizzPage extends StatefulWidget {
  final String id;
  final String team;

  QuizzPage({Key key, this.id, this.team}) : super(key: key);

  @override
  _QuizzPageState createState() => _QuizzPageState(id: id, team: team);
}

//class QuizzPage extends StatelessWidget {
class _QuizzPageState extends State<QuizzPage> {
  final String id;
  final String team;

  List<TextEditingController> quizzAnswersText =
      List.generate(5, (i) => TextEditingController());
  HashMap<String, String> quizzAnswers = new HashMap();
  TextEditingController _guessController = TextEditingController();
  CollectionReference quizzes =
      FirebaseFirestore.instance.collection('quizzes');

  _QuizzPageState({this.id, this.team});

  @override
  Widget build(BuildContext context) {
    void addGuess(String guess) async {
      var quiz = quizzes.doc(this.id);
      var snap = await quiz.snapshots().first;
      var city = snap.data()['current']['city'];
      var target = "responses.$team.$city";
      quiz.update({
        target: FieldValue.arrayUnion([
          {
            "guess": guess,
            "points": snap.data()['current']['points'],
          }
        ])
      }).then((value) => _guessController.clear());
    }

    void quizzChange() async {
      var quiz = quizzes.doc(this.id);
      var snap = await quiz.snapshots().first;
      var city = snap.data()['current']['city'];
      var target = "responses.$team.quiz.$city";

      quiz.update({
        target: quizzAnswers,
      }).then((value) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text('Svaren är sparade'),
          )));
    }

    return StreamBuilder<DocumentSnapshot>(
        stream: quizzes.doc(this.id).snapshots(),
        builder:
            (BuildContext context, AsyncSnapshot<DocumentSnapshot> snapshot) {
          if (snapshot.hasError) {
            return Text('Something went wrong');
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return loadingScreen();
          }

          Map<String, dynamic> data = snapshot.data.data();
          final String _currentCity = data['current']['city'];

          final int _currentPoint = data['current']['points'];
          final String _currentPointStr = _currentPoint.toString();

          final bool _showQuestions = data['current']['show_questions'];
          final quest = data['cities'][_currentCity]['questions'];

          final String _tip =
              data['cities'][_currentCity]['tips'][_currentPointStr];
          if (_showQuestions) {
            var maList = mapIndexed(quest, (index, d) {
              var alt;
              if (d['alternatives'] == null) {
                alt = [
                  TextField(
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                    controller: quizzAnswersText[index],
                    onChanged: (v) {
                      quizzAnswers[d['question']] = v;
                    },
                  ),
                ];
              } else {
                alt = d['alternatives'].map((a) {
                  return ListTile(
                    title: Text(a.toString()),
                    leading: Radio(
                      value: a.toString(),
                      groupValue: quizzAnswers[d['question']],
                      onChanged: (String value) {
                        quizzAnswers[d['question']] = value;
                        setState(() {});
                        //setState(() {
                        //  quizzAnswers[d['question']] = value;
                        //} );
                      },
                    ),
                  );
                });
              }
              return new Container(
                  padding: const EdgeInsets.all(10),
                  alignment: Alignment.centerLeft,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: Column(
                      children: [
                        Text(
                          d['question'],
                          style: TextStyle(fontSize: 20),
                        ),
                        ...alt,
                      ],
                    ),
                  ));
            });

            return Scaffold(
                appBar: AppBar(
                  title: Text("$team kör loket"),
                ),
                body: Container(
                  padding: const EdgeInsets.all(32),
                  child: SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: Row(
                        children: [
                          Expanded(
                            /*1*/
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                /*2*/
                                Container(
                                  padding: const EdgeInsets.only(
                                      top: 20, bottom: 10),
                                  child: Text(
                                    _currentCity,
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 30),
                                  ),
                                ),
                                ...maList,
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  child: ElevatedButton(
                                    child: Text('Spara'),
                                    onPressed: () {
                                      quizzChange();
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )),
                ));
          }
          if (_currentPoint != 0) {
            return Scaffold(
                appBar: AppBar(
                  title: Text("$team kör På Spåret"),
                ),
                body: SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: Container(
                      padding: const EdgeInsets.all(32),
                      child: Row(
                        children: [
                          Expanded(
                            /*1*/
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                /*2*/
                                Container(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Text(
                                    'Vart är vi påväg?',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 30),
                                  ),
                                ),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    Text('10', style: TextStyle(fontSize: 25)),
                                    Text('8', style: TextStyle(fontSize: 25)),
                                    Text('6', style: TextStyle(fontSize: 25)),
                                    Text('4', style: TextStyle(fontSize: 25)),
                                    Text('2', style: TextStyle(fontSize: 25)),
                                  ],
                                ),
                                LinearProgressIndicator(
                                  // 0.17, 0.34, 0.68, 0.85
                                  value: (6 - _currentPoint / 2) / 6,
                                  semanticsLabel: 'Linear progress indicator',
                                  backgroundColor: Colors.blue.shade400,
                                ),
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  child: Text(
                                    " " + _tip,
                                    style: TextStyle(fontSize: 20),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.only(top: 10),
                                  child: TextField(
                                    decoration: InputDecoration(
                                      border: OutlineInputBorder(),
                                      labelText: 'Gissning',
                                    ),
                                    controller: _guessController,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  child: ElevatedButton(
                                    child: Text('Gissa'),
                                    onPressed: () {
                                      addGuess(_guessController.text);
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )));
          } // currentPoint != 0
          return waitingScreen(team);
        });
  }
}

class QuizzControlPage extends StatefulWidget {
  final String id;

  QuizzControlPage({Key key, this.id}) : super(key: key);

  @override
  _QuizzControlPageState createState() => _QuizzControlPageState(id: id);
}

class _QuizzControlPageState extends State<QuizzControlPage> {
  final String id;

  String currentCity;
  int currentPoints = 0;
  bool showQuestions = false;
  CollectionReference quizzes =
      FirebaseFirestore.instance.collection('quizzes');

  _QuizzControlPageState({this.id});

  @override
  Widget build(BuildContext context) {
    void setCurrent() async {
      var quiz = quizzes.doc(this.id);
      var target = "current";
      quiz.update({
        target: {
          "city": currentCity,
          "points": currentPoints,
          "show_questions": showQuestions,
        }
      });
    }

    return StreamBuilder<DocumentSnapshot>(
        stream: quizzes.doc(this.id).snapshots(),
        builder:
            (BuildContext context, AsyncSnapshot<DocumentSnapshot> snapshot) {
          if (snapshot.hasError) {
            return Text('Something went wrong');
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return loadingScreen();
          }

          Map<String, dynamic> data = snapshot.data.data();
          List<String> cities = data['cities'].keys.toList();
          List<String> cityTip;
          currentCity = data['current']['city'];
          currentPoints = data['current']['points'];
          showQuestions = data['current']['show_questions'];

          if (currentCity != null) {
            cityTip = List<String>.from(
                data['cities'][currentCity]['tips'].keys.toList().map((v) {
              return v.toString();
            }).toList());
            cityTip.add("0");
          }

          return Scaffold(
              appBar: AppBar(
                title: Text("På Spåret Controller"),
              ),
              body: Container(
                padding: const EdgeInsets.all(32),
                child: Row(
                  children: [
                    Expanded(
                      /*1*/
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          /*2*/
                          Container(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Text(
                              "$id",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 20),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.only(top: 10),
                            child: Text(
                              "City",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(10),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                DropdownButton<String>(
                                  value: currentCity,
                                  onChanged: (value) {
                                    setState(() {
                                      currentCity = value;
                                      currentPoints = 0;
                                      showQuestions = false;
                                      setCurrent();
                                    });
                                  },
                                  items:
                                      cities.map<DropdownMenuItem<String>>((k) {
                                    return DropdownMenuItem<String>(
                                        value: k.toString(),
                                        child: Text(k.toString()));
                                  }).toList(),
                                ),
                                Spacer(),
                                DropdownButton<String>(
                                  value: currentPoints.toString(),
                                  onChanged: (value) {
                                    setState(() {
                                      currentPoints = int.parse(value);
                                      setCurrent();
                                    });
                                  },
                                  items: cityTip
                                      .map<DropdownMenuItem<String>>((k) {
                                    return DropdownMenuItem<String>(
                                        value: k.toString(),
                                        child: Text(k.toString()));
                                  }).toList(),
                                ),
                              ],
                            ),
                          ),
                          Container(
                              padding: const EdgeInsets.all(10),
                              child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text("Show Questions"),
                                    Switch(
                                      value: showQuestions,
                                      onChanged: (v) {
                                        setState(() {
                                          currentPoints = 0;
                                          showQuestions = v;
                                          setCurrent();
                                        });
                                      },
                                    ),
                                  ])),
                        ],
                      ),
                    ),
                  ],
                ),
              ));
        });
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title, this.id}) : super(key: key);
  final String title;
  final String id;

  @override
  _MyHomePageState createState() => _MyHomePageState(this.id);
}

class _MyHomePageState extends State<MyHomePage> {
  TextEditingController _quizzIdController = TextEditingController();
  final _quizzTeamController = TextEditingController();

  _MyHomePageState(String id) {
    _quizzIdController = TextEditingController(text: id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.all(20),
              child: TextField(
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Enter Teamname',
                ),
                controller: _quizzTeamController,
              ),
            ),
            Container(
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.all(20),
              child: TextField(
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Enter quizzcode',
                ),
                controller: _quizzIdController,
              ),
            ),
            Container(
              child: ElevatedButton(
                child: Text('Join Quizz'),
                autofocus: false,
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    "/q/" +
                        _quizzIdController.text +
                        "/" +
                        _quizzTeamController.text,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
