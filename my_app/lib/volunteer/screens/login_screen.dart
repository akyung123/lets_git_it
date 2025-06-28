
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PhoneLoginScreen extends StatefulWidget {
  const PhoneLoginScreen({super.key});

  @override
  State<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends State<PhoneLoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _smsCodeController = TextEditingController();

  String _verificationId = '';
  bool isCodeSent = false;
  bool isLoading = false;

  String _formatPhone(String input) {
    String phone = input.trim().replaceAll('-', '');
    if (!phone.startsWith('+')) {
      if (phone.startsWith('0')) {
        phone = '+82${phone.substring(1)}';
      }
    }
    return phone;
  }

  Future<void> sendVerificationCode() async {
    final input = _phoneController.text;
    final phone = _formatPhone(input);

    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('전화번호를 입력하세요.')),
      );
      return;
    }

    setState(() => isLoading = true);

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phone,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (PhoneAuthCredential credential) async {
        await FirebaseAuth.instance.signInWithCredential(credential);
        await _onLoginSuccess();
      },
      verificationFailed: (FirebaseAuthException e) {
        debugPrint('📛 인증 실패: ${e.code} / ${e.message}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('인증 실패: ${e.message}')),
        );
        setState(() => isLoading = false);
      },
      codeSent: (String verificationId, int? resendToken) {
        setState(() {
          _verificationId = verificationId;
          isCodeSent = true;
          isLoading = false;
        });
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        _verificationId = verificationId;
      },
    );
  }

  Future<void> verifySmsCode() async {
    final code = _smsCodeController.text.trim();
    if (code.isEmpty || _verificationId.isEmpty) return;

    setState(() => isLoading = true);

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId,
        smsCode: code,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
      await _onLoginSuccess();
    } on FirebaseAuthException catch (e) {
      debugPrint('📛 코드 인증 실패: ${e.code} / ${e.message}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('코드 인증 실패: ${e.message}')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _onLoginSuccess() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final uid = user.uid;
    final rawPhone = user.phoneNumber ?? '';

    // +82 → 010-1234-5678 형식 변환
    String localPhone = rawPhone.replaceFirst('+82', '0');
    if (localPhone.length == 11) {
      localPhone =
          '${localPhone.substring(0, 3)}-${localPhone.substring(3, 7)}-${localPhone.substring(7)}';
    }

    final userDoc = FirebaseFirestore.instance.collection('users').doc(uid);
    final docSnapshot = await userDoc.get();

    if (!docSnapshot.exists) {
      await userDoc.set({
        'fcmToken': 'fcm_token_001',
        'id': uid.substring(0, 2).toUpperCase(),
        'isAdmin': false,
        'isVerifiedVolunteer': false,
        'name': '이름없음',
        'phone': localPhone,
        'point': 0,
        'pointLogs': [],
        'role': true,
      });
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('로그인 성공!')),
    );

    Navigator.pushReplacementNamed(context, '/tab_volunteer');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('전화번호 로그인')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: '전화번호 (예: 01012345678 또는 +821012345678)',
              ),
            ),
            if (isCodeSent)
              TextField(
                controller: _smsCodeController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'SMS 인증 코드',
                ),
              ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: isCodeSent ? verifySmsCode : sendVerificationCode,
              child: isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(isCodeSent ? '코드 확인' : '인증코드 요청'),
            ),
          ],
        ),
      ),
    );
  }
}
