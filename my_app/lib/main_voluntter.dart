import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:my_app/firebase_options.dart';
import 'package:my_app/volunteer/screens/main_screen.dart'; // MainScreen 임포트

void main() async {
  print("--- 앱 시작: main() 함수 진입 (테스트 모드) ---");
  WidgetsFlutterBinding.ensureInitialized();
  print("WidgetsFlutterBinding.ensureInitialized() 완료.");

  // Firebase 앱이 이미 초기화되었는지 확인 후 초기화
  if (Firebase.apps.isEmpty) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      print("Firebase.initializeApp() 완료.");
    } catch (e) {
      print("Firebase 초기화 오류: $e");
      // Firebase 초기화 실패 시 사용자에게 알림을 줄 수 있는 UI를 여기에 추가
    }
  } else {
    print("Firebase 앱이 이미 초기화되어 있습니다. 다시 초기화하지 않습니다.");
  }

  try {
    await dotenv.load();
    print("dotenv.load() 완료.");
  } catch (e) {
    print("DotEnv 로드 오류: $e");
    // .env 파일 로드 실패 시 처리
  }

  print("runApp() 호출 준비.");
  runApp(const MyApp());
  print("--- runApp() 호출 완료 ---");
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    print("MyApp.build() 호출됨.");
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      // Firebase 로그인 상태 확인 없이 바로 MainScreen으로 이동
      home: const MainScreen(),
      routes: {
        // 이 라우트는 이제 PhoneLoginScreen에서 직접 호출하지 않는 한 사용되지 않습니다.
        '/tab_volunteer': (context) => const MainScreen(),
      },
    );
  }
}

// MyHomePage는 현재 앱의 핵심 로직과 직접적인 관련이 없는 것으로 보이며,
// PhoneLoginScreen이 로그인 기능을 담당한다면 이 위젯은 사용되지 않을 수 있습니다.
// 만약 MyHomePage가 로그인 후의 메인 화면이라면, 위 StreamBuilder에서 사용하도록 수정해야 합니다.
class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    print("MyHomePage.build() 호출됨. 현재 카운터: $_counter");
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'You have pushed the button this many times:',
            ),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}