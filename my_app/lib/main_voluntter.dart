import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart'; // FirebaseAuth 추가
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:my_app/firebase_options.dart';
import 'package:my_app/volunteer/screens/login_screen.dart';
// TODO: 로그인 후 보여줄 메인 화면 import 추가 (예: home_screen.dart)
// import 'package:my_app/volunteer/screens/home_screen.dart';


void main() async {
  print("--- 앱 시작: main() 함수 진입 ---");
  WidgetsFlutterBinding.ensureInitialized();
  print("WidgetsFlutterBinding.ensureInitialized() 완료.");

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print("Firebase.initializeApp() 완료.");
  } catch (e) {
    print("Firebase 초기화 오류: $e");
    // Firebase 초기화 실패 시 사용자에게 알림을 줄 수 있는 UI를 여기에 추가
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
      home: StreamBuilder<User?>( // Firebase 인증 상태 변화 감지
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          print("StreamBuilder: ConnectionState - ${snapshot.connectionState}, HasError - ${snapshot.hasError}, HasData - ${snapshot.hasData}");

          // Firebase 초기화 및 인증 상태 확인 중일 때 로딩 스피너 표시
          if (snapshot.connectionState == ConnectionState.waiting) {
            print("StreamBuilder: 인증 상태 확인 중 (ConnectionState.waiting).");
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }
          // 오류 발생 시
          if (snapshot.hasError) {
            print("StreamBuilder: Firebase Auth Stream 오류 발생: ${snapshot.error}");
            return Scaffold(
              body: Center(
                child: Text('인증 오류가 발생했습니다. 앱을 다시 시작해주세요. 오류: ${snapshot.error}'),
              ),
            );
          }
          // 사용자가 로그인되어 있으면 (snapshot.hasData && snapshot.data != null)
          // HomeScreen (메인 화면)으로 이동합니다.
          if (snapshot.hasData && snapshot.data != null) {
            print("StreamBuilder: 사용자 로그인됨. UID: ${snapshot.data!.uid}");
            // TODO: 여기에 로그인 성공 후 보여줄 메인 화면 위젯을 넣어주세요.
            // 예를 들어, return const HomeScreen();
            return const Scaffold(
              body: Center(
                child: Text("로그인 완료! 메인 화면으로 이동해야 합니다. (TODO: HomeScreen 연결)"),
              ),
            );
          }
          // 로그인된 사용자가 없으면 PhoneLoginScreen으로 이동합니다.
          print("StreamBuilder: 사용자 로그인되지 않음. PhoneLoginScreen으로 이동.");
          return const PhoneLoginScreen();
        },
      ),
      // 라우트 정의는 필요에 따라 추가하세요.
      // routes: {
      //   '/home': (context) => const HomeScreen(),
      //   '/login': (context) => const PhoneLoginScreen(),
      // },
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