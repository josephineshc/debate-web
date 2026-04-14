import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:screenshot/screenshot.dart';
import 'dart:html' as html;
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

enum SubjectMode { search, custom }

void main() {
  runApp(const MyApp());
}

class FullWidthTrackShape extends RoundedRectSliderTrackShape {
  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final double trackHeight = sliderTheme.trackHeight!;
    final double trackLeft = offset.dx;
    final double trackTop =
        offset.dy + (parentBox.size.height - trackHeight) / 2;
    final double trackWidth = parentBox.size.width;
    return Rect.fromLTWH(trackLeft, trackTop, trackWidth, trackHeight);
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  ChatMessage({required this.text, required this.isUser});
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color.fromARGB(255, 255, 255, 255),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: ''),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final ScrollController _categoryScrollController = ScrollController();
  final ScreenshotController _screenshotController = ScreenshotController();
  double _oppCertainty = 20;
  double _userInitialCertainty = 15;
  double _userResearchCertainty = 15;
  String _oppSide = 'pros';
  String _persona = 'sympathetic';
  String _selectedTopic = "None Selected";
  late FocusNode _searchFocusNode;
  bool _isSearchFocused = false;
  bool _isCustomMode = false;
  bool _isSaveButtonError = false;

  bool _isDebateStarted = false;
  bool _isAiGenerating = false;
  String _aiConstructiveText = "";
  String _subjectIntroduction = "Select or write a subject to start";
  final TextEditingController _userConstructiveController =
      TextEditingController();

  Timer? _crossfireTimer;
  int _secondsRemaining = 180;
  bool _isCrossfireStarted = false;
  bool _isCrossfireStarted2 = false;
  bool _isCrossfireStarted3 = false;

  int _userLetterCount = 0;
  final int _charLimit = 1000;

  List<ChatMessage> _crossfireMessages = [];
  List<ChatMessage> _crossfireMessages2 = [];
  List<ChatMessage> _crossfireMessages3 = [];
  bool _isChatAiGenerating = false;
  bool _isChatErrorFlash = false;

  final ScrollController _chatScrollController = ScrollController();
  final TextEditingController _chatInputController = TextEditingController();

  bool _isRebuttalStarted = false;
  bool _isAiRebuttalGenerating = false;
  bool _hasStartedAiRebuttal = false;
  String _aiRebuttalText = "";
  int _userRebuttalLetterCount = 0;
  final TextEditingController _userRebuttalController = TextEditingController();
  bool _isRebuttalSaved = false;

  bool _isSummaryStarted = false;
  bool _isAiSummaryGenerating = false;
  bool _hasStartedAiSummary = false;
  String _aiSummaryText = "";
  int _userSummaryLetterCount = 0;
  final TextEditingController _userSummaryController = TextEditingController();
  bool _isSummarySaved = false;

  bool _isFinalFocusStarted = false;
  bool _isAiFinalFocusGenerating = false;
  bool _hasStartedAiFinalFocus = false;
  String _aiFinalFocusText = "";
  int _userFinalFocusLetterCount = 0;
  bool _isFinalFocusSaved = false;
  final TextEditingController _userFinalFocusController =
      TextEditingController();

  bool _isJudgeLoading = false;
  Map<String, dynamic>? _judgeResult;

  bool _isCertaintyAnswered = false;
  double? _userFinalCertainty;

  int _roundNumber = 1;
  List<Map<String, dynamic>> _debateHistory = [];

  static const String _backendUrl = 'https://debate-backend-j5z2.onrender.com';

  String _getPersonaPrompt() {
    switch (_persona) {
      case 'Dogmatic':
        return """You are a debate opponent who holds a firm, unwavering position on the topic. You are highly certain of your views and resistant to changing them regardless of the arguments presented. When faced with counterevidence, you do not engage with its content directly — instead you generate procedural objections, question the source's credibility, or reframe the claim so it no longer threatens your position. You never concede a point. You argue with conviction and confidence, treating your position as self-evidently correct. Your goal is not to find common ground but to defend your stance against all challenges.""";
      case 'Analytical':
        return """You are a debate opponent who engages with arguments rigorously and on their merits. You have a high standard of evidence and will press directly into the core of the opposing case rather than its weaker edges. When a claim is vague or unsupported, you demand clarification and evidence. When an argument is well-constructed and evidentially supported, you acknowledge its force before responding. You do not dismiss arguments without engagement — you scrutinise them carefully and respond with precision. Your goal is to find the strongest version of the debate through rigorous exchange.""";
      case 'Open-Minded':
        return """You are a debate opponent who holds a position on the topic but remains genuinely open to compelling arguments. You actively consider evidence that challenges your view rather than dismissing it. When the opposing argument is strong and well-reasoned, you acknowledge its validity and may adjust your position accordingly. You are willing to concede points that you cannot rebut, and your certainty visibly decreases across the debate when faced with sustained quality argumentation. Your goal is to engage honestly with the exchange, updating your position in response to the strength of the arguments presented rather than defending a fixed stance at all costs.""";
      default:
        return "You are a professional debater arguing your assigned side.";
    }
  }

  Future<String> _callGemini(String prompt) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_backendUrl/api/generate'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'prompt': prompt}),
          )
          .timeout(const Duration(seconds: 60));
      final data = jsonDecode(response.body);
      return data['candidates'][0]['content']['parts'][0]['text'] ?? '';
    } catch (e) {
      throw Exception('Failed to connect to server: $e');
    }
  }

  final Map<String, List<String>> _allTopics = {
    'Education': [
      'Should phones be banned in school?',
      'Should we grade effort or just the final result?',
      'Should teachers be allowed to punish students?',
      'Should religious studies be mandatory?',
      'Should teachers be paid based on their performance?',
      'Is remote learning actually better for introverted students?',
    ],
    'Technology': [
      'Should constant internet access a basic human right?',
      'Should there be online anonymity?',
      'Is AI therapy good for lonely individuals?',
      'Is artificial intelligence a threat to human creativity?',
      'Are tech companies more powerful than governments?',
    ],
    'Social Media': [
      'Should there be a compulsory age limit for using social media?',
      'Should parents be allowed to monitor their kids\' activities on social media',
      'Do viral challenges encourage creativity?',
      'Is "cancel culture" fair?',
      'Are social media influencers good role models?',
    ],
    'Politics': [
      'Should citizens have to pass a political knowledge test in order to vote?',
      'Should wealthy nations accept climate refugees?',
      'Does wealthy nations need stricter imigration policies?',
      'Is democracy the best form of government?',
      'Should a good leader be allowed to rule more than his term?',
      'Should politicians be mandated to publicly display their wealth?',
      'Should the government limit corporate donations to political campaigns?',
      'Should traditional leaders have political power in modern society?',
    ],
    'Social & Culture': [
      'Is modern culture taking away respect for elders?',
      'Is individual freedom more important than community values?',
      'Should dress codes exist in schools and public spaces?',
      'Is the rise of “woke” culture good?',
    ],
    'Ethics': [
      'Is lying for a good cause morally justified?',
      'Are humans naturally selfish?',
      'Should people be judged by their past mistakes?',
      'Should people be held accountable for beliefs, not just actions?',
      'Is capital punishment a morally acceptable form of justice?',
      'Should empathy ever have limits?',
    ],
    'Science': [
      'Is it ethical to use animals for scientific research?',
      'Should humans be allowed to extract resources from space?',
      'Is cloning of pets an acceptable way to cope with pet loss?',
    ],
    'Environment': [
      'Is recycling effective?',
      'Should developing countries follow the same climate rules as developed countries?',
      'Should plastic packaging be banned in all supermarkets?',
    ],
    'Economics': [
      'Is globalization a good thing?',
      'Is population decline a good thing in modern society?',
      'Should colonization of space be allowed?',
      'Should billionaires be taxed more?',
      'Should governments impose population controls?'
          'Is federalism better than a centralized system of government?',
      'Is the rise of populism a threat to democracy?',
    ],
    'Business': [
      'Should small businesses be exempt from minimum wage requirements?',
      'Should age of retirement be raised?',
    ],
    'Gender & Identity': [
      'Are single-gender schools a better option?',
      'Should we add gender-neutral categories in professional sports?',
      'Should feminism be intersectional?',
      'Does social media impact gender identity?',
      'Should there ne quotas for women in government?',
      'Should there be a legal minimum age for beginning a medical gender transition?',
    ],
    'Human Rights': [
      'Is healthcare a basic human right?',
      'Should euthanasia be legalised?',
      'Is a universal basic income a good idea?',
    ],
    'History': [
      'Should there be a single standardized national history textbook for all schools?',
      'Is it better to overlook past historical grievances for the sake of future benefits?',
      'Should history lessons include ethical judgements?',
      'Was the Industrial Revolution good for society?',
      'Was the United States right to drop atomic bombs on Japan?',
    ],
    'Sports': [
      'Is the use of performance-enhancing drugs acceptable in sports if everyone uses them?',
      'Should baseball games be shortened to appeal to younger audiences?',
      'Does the "human element" of an umpire\'s strike zone add essential character to baseball?',
    ],
  };

  void _filterSearch(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredTopics = _allTopics;
      } else {
        Map<String, List<String>> tempMap = {};
        _allTopics.forEach((category, topics) {
          List<String> matchingTopics =
              topics
                  .where(
                    (topic) =>
                        topic.toLowerCase().contains(query.toLowerCase()),
                  )
                  .toList();

          if (category.toLowerCase().contains(query.toLowerCase()) ||
              matchingTopics.isNotEmpty) {
            tempMap[category] =
                matchingTopics.isNotEmpty ? matchingTopics : topics;
          }
        });
        _filteredTopics = tempMap;
      }
    });
  }

  final TextEditingController _customSubjectController =
      TextEditingController();
  void _generateIntroduction(String topic) {
    setState(() {
      _subjectIntroduction = 'Starting introduction...';
    });
    Future.delayed(const Duration(seconds: 1), () {
      setState(() {
        _subjectIntroduction =
            "Welcome to the debate on '$topic'. Let's start the constructive round.";
      });
    });
  }

  late Map<String, List<String>> _filteredTopics;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _otherController = TextEditingController();

  final Map<String, bool> _subjectChoices = {
    'curiosity': false,
    'perspective-taking': false,
    'self-correction': false,
    'resolution': false,
    'other': false,
  };

  @override
  void initState() {
    super.initState();

    _filteredTopics = _allTopics;
    _searchFocusNode = FocusNode();

    _searchFocusNode.addListener(() {
      setState(() {
        _isSearchFocused = _searchFocusNode.hasFocus;
      });
    });

    _customSubjectController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _categoryScrollController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  //✅ Constructive Box Functions
  void _updateLetterCount(String text) {
    setState(() {
      _userLetterCount = text.length;
    });
  }

  void _onStartDebate() async {
    setState(() {
      _isDebateStarted = true;
      _isAiGenerating = true;
      _isCrossfireStarted = false;
      _secondsRemaining = 180;
      _userConstructiveController.clear();
      _aiConstructiveText = "";
    });
    final history = _buildHistoryContext();

    final prompt = """
    ${_getPersonaPrompt()}
    Topic: $_selectedTopic. 
    Your Side: $_oppSide. 
    Your Persona: $_persona. 
    Confidence Level: $_oppCertainty%
    This is Round $_roundNumber.
    $history
    Task: Write a strong opening constructive argument. 
    Constraint: Keep it under 1000 characters.
  """;
    try {
      final text = await _callGemini(prompt);

      setState(() {
        _aiConstructiveText = text;
        _isAiGenerating = false;
      });
    } catch (e) {
      setState(() {
        _aiConstructiveText = "Error connecting to Gemini: $e";
        _isAiGenerating = false;
      });
    }
  }

  Widget _buildBox({
    required String title,
    required bool isUser,
    bool isLoading = false,
    required Widget content,
    required int charCount,
    VoidCallback? onSave,
    required bool isReadOnly,
  }) {
    return Container(
      height: 220,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:
            (isUser && isReadOnly)
                ? const Color(0xFFC0C5CA)
                : const Color(0xFFD9DEE3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              Text(
                "${charCount ?? 0}/$_charLimit",
                style: const TextStyle(fontSize: 10, color: Colors.black54),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child:
                      isLoading
                          ? const Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black54,
                            ),
                          )
                          : ClipRect(
                            child: SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              child: DefaultTextStyle(
                                style: TextStyle(
                                  fontSize: 12,
                                  color:
                                      (isUser && _isCrossfireStarted)
                                          ? Colors.black54
                                          : Colors.black,
                                  height: 1.4,
                                ),
                                child: content,
                              ),
                            ),
                          ),
                ),

                if (isUser && !isReadOnly && onSave != null)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color:
                            _isSaveButtonError
                                ? Colors.redAccent
                                : const Color(0xFFD9DEE3).withOpacity(0.8),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: Icon(
                          Icons.save_outlined,
                          size: 20,
                          color:
                              _isSaveButtonError
                                  ? Colors.white
                                  : Colors.black87,
                        ),
                        onPressed: () {
                          bool isAiStillWorking =
                              _isAiGenerating ||
                              _isAiRebuttalGenerating ||
                              _isAiSummaryGenerating ||
                              _isAiFinalFocusGenerating;

                          if (isAiStillWorking) {
                            setState(() => _isSaveButtonError = true);
                            Future.delayed(
                              const Duration(milliseconds: 500),
                              () {
                                if (mounted)
                                  setState(() => _isSaveButtonError = false);
                              },
                            );
                            return;
                          }

                          if (charCount > 0 && charCount <= _charLimit) {
                            onSave();
                          }
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  //✅ Crossfire Functions
  Widget _buildCrossfireBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
      decoration: BoxDecoration(
        color: Color.fromARGB(255, 255, 200, 191),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          const Text(
            "Crossfire",
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          Text(
            "${_formatTime(_secondsRemaining)} ⏳",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  void _startCrossfire() {
    setState(() {
      _isCrossfireStarted = true;
    });

    _crossfireTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_secondsRemaining > 0) {
          _secondsRemaining--;
        } else {
          _onCrossfireFinished();
        }
      });
    });
  }

  void _onCrossfireFinished() {
    if (_hasStartedAiRebuttal) return;

    setState(() {
      _hasStartedAiRebuttal = true;
      _isRebuttalStarted = true;
      _isAiRebuttalGenerating = true;
    });
    _crossfireTimer?.cancel();
    _scrollToBottom();
    _generateAiRebuttal();
  }

  //✅ Rebuttal Box Generate
  void _generateAiRebuttal() async {
    String crossfire1 = _crossfireMessages
        .map((m) => "${m.isUser ? 'User' : 'Opponent'}: ${m.text}")
        .join("\n");

    final prompt = """
    The crossfire round has ended.
    ${_getPersonaPrompt()}
    Topic: $_selectedTopic. 
    Your Side: $_oppSide.

    Full Debate History So Far:
    [Constructive - Opponent]:$_aiConstructiveText
    [Constructive - User]: ${_userConstructiveController.text}
    [Crossfire 1]: $crossfire1

    Write a Rebuttal argument (max 1000 chars) that addresses the user's points and reinforces your position.
  """;

    try {
      final text = await _callGemini(prompt);
      setState(() {
        _aiRebuttalText = text;
        _isAiRebuttalGenerating = false;
      });
    } catch (e) {
      setState(() {
        _aiRebuttalText = "Error: $e";
        _isAiRebuttalGenerating = false;
      });
      _scrollToBottom();
    }
  }

  void _startCrossfire2() {
    setState(() {
      _isRebuttalSaved = true;
      _isCrossfireStarted2 = true;
      _secondsRemaining = 180;
    });
    _crossfireTimer?.cancel();
    _crossfireTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_secondsRemaining > 0) {
          _secondsRemaining--;
        } else {
          _crossfireTimer?.cancel();
          _onCrossfireFinished2();
        }
      });
    });
  }

  void _onCrossfireFinished2() {
    if (_hasStartedAiSummary) return;

    setState(() {
      _hasStartedAiSummary = true;
      _isSummaryStarted = true;
      _isAiSummaryGenerating = true;
    });
    _crossfireTimer?.cancel();
    _scrollToBottom();
    _generateAiSummary();
  }

  //✅ Summary Box Generate
  void _generateAiSummary() async {
    String crossfire1 = _crossfireMessages
        .map((m) => "${m.isUser ? 'User' : 'Opponent'}: ${m.text}")
        .join("\n");
    String crossfire2 = _crossfireMessages2
        .map((m) => "${m.isUser ? 'User' : 'Opponent'}: ${m.text}")
        .join("\n");

    final prompt = """
    The crossfire round has ended. 
    ${_getPersonaPrompt()}
    Topic: $_selectedTopic. 
    Your Side: $_oppSide. 
    
    Full Debate History So Far:
    [Constructive - Opponent]:$_aiConstructiveText
    [Constructive - User]: ${_userConstructiveController.text}
    [Crossfire 1]: $crossfire1
    [Rebuttal - Opponent]:$_aiRebuttalText
    [Rebuttal - User]: ${_userRebuttalController.text}
    [Crossfire 2]: $crossfire2
    
    Write a final Summary argument (max 1000 chars) that focuses on defending (or answering) the most important arguments and tells the judge how they should be evaluated.
  """;

    try {
      final text = await _callGemini(prompt);
      setState(() {
        _aiSummaryText = text;
        _isAiSummaryGenerating = false;
      });
    } catch (e) {
      setState(() {
        _aiSummaryText = "Error: $e";
        _isAiSummaryGenerating = false;
      });
      _scrollToBottom();
    }
  }

  void _startCrossfire3() {
    setState(() {
      _isSummarySaved = true;
      _isCrossfireStarted3 = true;
      _secondsRemaining = 180;
    });
    _crossfireTimer?.cancel();
    _crossfireTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_secondsRemaining > 0) {
          _secondsRemaining--;
        } else {
          _crossfireTimer?.cancel();
          _onCrossfireFinished3();
        }
      });
    });
  }

  void _onCrossfireFinished3() {
    if (_hasStartedAiFinalFocus) return;

    _crossfireTimer?.cancel();

    setState(() {
      _hasStartedAiSummary = true;
      _isFinalFocusStarted = true;
      _isAiFinalFocusGenerating = true;
    });
    _scrollToBottom();
    _generateFinalFocusSummary();
  }

  //✅ FinalFocus Box Generate
  void _generateFinalFocusSummary() async {
    String crossfire1 = _crossfireMessages
        .map((m) => "${m.isUser ? 'User' : 'Opponent'}: ${m.text}")
        .join("\n");
    String crossfire2 = _crossfireMessages2
        .map((m) => "${m.isUser ? 'User' : 'Opponent'}: ${m.text}")
        .join("\n");
    String crossfire3 = _crossfireMessages3
        .map((m) => "${m.isUser ? 'User' : 'Opponent'}: ${m.text}")
        .join("\n");

    final prompt = """
    The crossfire round has ended. 
    ${_getPersonaPrompt()}
    Topic: $_selectedTopic. 
    Your Side: $_oppSide. 
    
    Full Debate History So Far:
    [Constructive - Opponent]:$_aiConstructiveText
    [Constructive - User]: ${_userConstructiveController.text}
    [Crossfire 1]: $crossfire1
    [Rebuttal - Opponent]:$_aiRebuttalText
    [Rebuttal - User]: ${_userRebuttalController.text}
    [Crossfire 2]: $crossfire2
    [Summary - Opponent]:$_aiSummaryText
    [Summary - User]: ${_userSummaryController.text}
    [Crossfire 3]: $crossfire3
    
    This should be in maximum 1000 characters. that focuses the debate on 1-2 arguments. Impact calculus is a must. Write the ballot for the judge.
  """;

    try {
      final text = await _callGemini(prompt);
      setState(() {
        _aiFinalFocusText = text;
        _isAiFinalFocusGenerating = false;
      });
    } catch (e) {
      setState(() {
        _aiFinalFocusText = "Error: $e";
        _isAiFinalFocusGenerating = false;
      });
    }
  }

  //✅ Chat History Update
  void _sendChatMessage(String text) async {
    if (text.trim().isEmpty || _secondsRemaining <= 0) return;

    if (_isChatAiGenerating) {
      setState(() => _isChatErrorFlash = true);
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) setState(() => _isChatErrorFlash = false);
      });
      return;
    }

    List<ChatMessage> targetList;
    String phaseContext = "";

    if (_isCrossfireStarted3) {
      targetList = _crossfireMessages3;
      phaseContext = "This is the 3rd crossfire round after summaries.";
    } else if (_isCrossfireStarted2) {
      targetList = _crossfireMessages2;
      phaseContext = "This is the 2nd crossfire round after rebuttals.";
    } else {
      targetList = _crossfireMessages;
      phaseContext = "This is the 1st crossfire round.";
    }

    setState(() {
      _isChatAiGenerating = true;
      targetList.add(ChatMessage(text: text, isUser: true));
      _chatInputController.clear();
    });
    _scrollToBottom();

    final chatPrompt =
        "${_getPersonaPrompt()} $phaseContext Debate Topic: $_selectedTopic. Your Side: $_oppSide. Respond to this argument in 2 sentences: $text";
    try {
      final text = await _callGemini(chatPrompt);
      setState(() {
        targetList.add(ChatMessage(text: text, isUser: false));
        _isChatAiGenerating = false;
      });
      _scrollToBottom();
    } catch (e) {
      setState(() => _isChatAiGenerating = false);
      debugPrint(e.toString());
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Widget _buildChatBubble(ChatMessage msg) {
    return Align(
      alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        decoration: BoxDecoration(
          color:
              msg.isUser
                  ? const Color.fromARGB(255, 222, 218, 239)
                  : const Color.fromARGB(255, 205, 175, 197),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
            bottomLeft: msg.isUser ? const Radius.circular(12) : Radius.zero,
            bottomRight: msg.isUser ? Radius.zero : const Radius.circular(12),
          ),
        ),
        child: Text(
          msg.text,
          style: const TextStyle(fontSize: 14, color: Colors.black87),
        ),
      ),
    );
  }

  Widget _buildChatInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _chatInputController,
                enabled: _secondsRemaining > 0 && !_isChatAiGenerating,
                decoration: const InputDecoration(
                  hintText: "Type your response...",
                  border: InputBorder.none,
                ),
                onSubmitted: _sendChatMessage,
              ),
            ),
            AnimatedContainer(
              duration: const Duration(microseconds: 200),
              decoration: BoxDecoration(
                color:
                    _isChatErrorFlash ? Colors.redAccent : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: Icon(
                  Icons.send_rounded,
                  color: _isChatErrorFlash ? Colors.white : Colors.blue,
                ),
                onPressed: () => _sendChatMessage(_chatInputController.text),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(int seconds) {
    int mins = seconds ~/ 60;
    int secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  //✅ Debate Functions
  List<Widget> _buildDebateRound() {
    return [
      const SizedBox(height: 20),
      _buildSectionHeader("ROUND $_roundNumber"),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
        decoration: BoxDecoration(
          color: Color.fromARGB(255, 191, 217, 255),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: Text(
            "Constructive Round",
            style: TextStyle(
              color: Color.fromARGB(255, 22, 77, 105),
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ),
      const SizedBox(height: 20),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _buildBox(
              title: "Constructive",
              isUser: false,
              isLoading: _isAiGenerating,
              content: Text(_aiConstructiveText ?? ""),
              charCount: (_aiConstructiveText ?? "").length,
              isReadOnly: false,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: _buildBox(
              title: "Constructive",
              isUser: true,
              isReadOnly: _isCrossfireStarted,
              content: TextField(
                controller: _userConstructiveController,
                enabled: !_isCrossfireStarted,
                maxLines: null,
                maxLength: _charLimit,
                scrollPhysics: const BouncingScrollPhysics(),
                keyboardType: TextInputType.multiline,
                style: const TextStyle(fontSize: 12),
                onChanged: (text) {
                  setState(() {
                    _userLetterCount = text.length;
                  });
                },
                decoration: const InputDecoration(
                  hintText:
                      "Enter your argument.\nYou cannot change this once you save it.",
                  hintStyle: TextStyle(fontSize: 12),
                  counterText: "",
                  border: InputBorder.none,
                  isDense: true,
                ),
              ),
              charCount: _userLetterCount,
              onSave: _startCrossfire,
            ),
          ),
        ],
      ),
      const SizedBox(height: 30),
      _buildCrossfireBar(),
      if (_isCrossfireStarted) ...[
        const SizedBox(height: 20),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _crossfireMessages.length,
          itemBuilder: (context, index) {
            return _buildChatBubble(_crossfireMessages[index]);
          },
        ),
      ],
      if (_isRebuttalStarted) ...[
        const SizedBox(height: 40),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
          decoration: BoxDecoration(
            color: Color.fromARGB(255, 191, 217, 255),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Text(
                "Rebuttal Round",
                style: TextStyle(
                  color: Color.fromARGB(255, 22, 77, 105),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildBox(
                title: "Rebuttal",
                isUser: false,
                isLoading: _isAiRebuttalGenerating,
                content: Text(_aiRebuttalText),
                charCount: _aiRebuttalText.length,
                isReadOnly: false,
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: _buildBox(
                title: "Rebuttal",
                isUser: true,
                isReadOnly: _isRebuttalSaved,
                content: TextField(
                  controller: _userRebuttalController,
                  enabled: !_isRebuttalSaved,
                  maxLines: null,
                  maxLength: _charLimit,
                  style: const TextStyle(fontSize: 12),
                  onChanged:
                      (val) =>
                          setState(() => _userRebuttalLetterCount = val.length),
                  decoration: const InputDecoration(
                    hintText: "Enter your rebuttal...",
                    counterText: "",
                    border: InputBorder.none,
                  ),
                ),
                charCount: _userRebuttalLetterCount,
                onSave: _startCrossfire2,
              ),
            ),
          ],
        ),
        if (_isCrossfireStarted2) ...[
          const SizedBox(height: 30),
          _buildCrossfireBar(),
          const SizedBox(height: 20),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _crossfireMessages2.length,
            itemBuilder:
                (context, index) =>
                    _buildChatBubble(_crossfireMessages2[index]),
          ),
        ],
        if (_isSummaryStarted) ...[
          const SizedBox(height: 40),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 191, 217, 255),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Text(
                  "Summary Round",
                  style: TextStyle(
                    color: Color.fromARGB(255, 22, 77, 105),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildBox(
                  title: "Summary",
                  isUser: false,
                  isLoading: _isAiSummaryGenerating,
                  content: Text(_aiSummaryText),
                  charCount: _aiSummaryText.length,
                  isReadOnly: false,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _buildBox(
                  title: "Summary",
                  isUser: true,
                  isReadOnly: _isSummarySaved,
                  content: TextField(
                    controller: _userSummaryController,
                    enabled: !_isSummarySaved,
                    maxLines: null,
                    maxLength: _charLimit,
                    style: const TextStyle(fontSize: 12),
                    onChanged:
                        (val) => setState(
                          () => _userSummaryLetterCount = val.length,
                        ),
                    decoration: const InputDecoration(
                      hintText: "Enter your summary...",
                      counterText: "",
                      border: InputBorder.none,
                    ),
                  ),
                  charCount: _userSummaryLetterCount,
                  onSave: _startCrossfire3,
                ),
              ),
            ],
          ),
          if (_isCrossfireStarted3) ...[
            const SizedBox(height: 30),
            _buildCrossfireBar(),
            const SizedBox(height: 20),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _crossfireMessages3.length,
              itemBuilder:
                  (context, index) =>
                      _buildChatBubble(_crossfireMessages3[index]),
            ),
          ],
          if (_isFinalFocusStarted) ...[
            const SizedBox(height: 40),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 249, 197, 79),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Text(
                  "Final Focus",
                  style: TextStyle(
                    color: Color.fromARGB(255, 14, 49, 130),
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildBox(
                    title: "Final Focus",
                    isUser: false,
                    isLoading: _isAiFinalFocusGenerating,
                    content: Text(_aiFinalFocusText),
                    charCount: _aiFinalFocusText.length,
                    isReadOnly: false,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: _buildBox(
                    title: "Final Focus",
                    isUser: true,
                    isReadOnly: _isFinalFocusSaved,
                    content: TextField(
                      controller: _userFinalFocusController,
                      enabled: !_isFinalFocusSaved,
                      maxLines: null,
                      maxLength: _charLimit,
                      style: const TextStyle(fontSize: 12),
                      onChanged:
                          (val) => setState(
                            () => _userFinalFocusLetterCount = val.length,
                          ),
                      decoration: const InputDecoration(
                        hintText:
                            "Write your final impact calculus.\n Include ballot for the judge...",
                        counterText: "",
                        border: InputBorder.none,
                      ),
                    ),
                    charCount: _userFinalFocusLetterCount,
                    onSave: () {
                      setState(() {
                        _isFinalFocusSaved = true;
                      });
                      _triggerJudge();
                    },
                  ),
                ),
              ],
            ),
          ],
          if (_isJudgeLoading) ...[
            const SizedBox(height: 40),
            const Center(
              child: Column(
                children: [
                  CircularProgressIndicator(color: Colors.blueAccent),
                  SizedBox(height: 16),
                  Text(
                    "The Judge is deliberating and reviewing the transcript...",
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (_judgeResult != null) ...[
            _buildJudgeUI(),
            const SizedBox(height: 40),
            _buildFinalActionButtons(),
          ],
          const SizedBox(height: 100),
        ],
      ],
    ];
  }

  //✅ Guide Book
  Widget _buildDots(PageController controller) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        double currentPage = controller.hasClients ? controller.page ?? 0 : 0;
        bool isActive = index == currentPage.round();

        return AnimatedContainer(
          duration: const Duration(microseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? Colors.black : Colors.grey.shade300,
          ),
        );
      }),
    );
  }

  void _showGuidePopup(BuildContext context) {
    final PageController pageController = PageController();

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Guide",
      barrierColor: Colors.black.withOpacity(0.05),
      pageBuilder: (context, anim1, anim2) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 60, right: 20),
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    width: 700,
                    height: 500,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 40,
                          ), // Space for arrows
                          child: Column(
                            children: [
                              Expanded(
                                child: PageView(
                                  controller: pageController,
                                  onPageChanged: (index) => setState(() {}),
                                  children: [
                                    InteractiveViewer(
                                      child: Image.asset(
                                        'assets/images/guide_page2.jpg',
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                    InteractiveViewer(
                                      child: Image.asset(
                                        'assets/images/guide_page3.jpg',
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                    InteractiveViewer(
                                      child: Image.asset(
                                        'assets/images/guide_page1.jpg',
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              _buildDots(pageController),
                              const SizedBox(height: 12),
                            ],
                          ),
                        ),

                        Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            icon: const Icon(
                              Icons.chevron_left,
                              color: Colors.grey,
                              size: 30,
                            ),
                            onPressed: () {
                              pageController.previousPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            },
                          ),
                        ),

                        Align(
                          alignment: Alignment.centerRight,
                          child: IconButton(
                            icon: const Icon(
                              Icons.chevron_right,
                              color: Colors.grey,
                              size: 30,
                            ),
                            onPressed: () {
                              pageController.nextPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            },
                          ),
                        ),

                        Positioned(
                          top: 8,
                          right: 8,
                          child: IconButton(
                            icon: const Icon(Icons.close, size: 30),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return FadeTransition(
          opacity: anim1,
          child: ScaleTransition(
            scale: anim1,
            alignment: Alignment.topRight,
            child: child,
          ),
        );
      },
    );
  }

  String _sanitize(String s) =>
      s
          .replaceAll('\r', ' ')
          .replaceAll('\n', ' ')
          .replaceAll('\t', ' ')
          .trim();

  String _formatCrossfire(List<ChatMessage> msgs) =>
      msgs.isEmpty
          ? '(none)'
          : msgs
              .map(
                (m) =>
                    "${m.isUser ? 'User' : 'Opponent'}: ${_sanitize(m.text)}",
              )
              .join(' | ');

  String _buildHistoryContext() {
    if (_debateHistory.isEmpty) return '';
    final buffer = StringBuffer();
    buffer.writeln(
      'PREVIOUS ROUNDS CONTEXT (for continuity — build on these, do not repeat them):',
    );
    for (final round in _debateHistory) {
      buffer.writeln(
        '--- Round ${round['round']} (Topic: ${round['topic']}) ---',
      );
      buffer.writeln(
        'Constructive (Opponent): ${_sanitize(round['constructive']['ai'] ?? '')}',
      );
      buffer.writeln(
        'Constructive (User): ${_sanitize(round['constructive']['user'] ?? '')}',
      );
      buffer.writeln(
        'Rebuttal (Opponent): ${_sanitize(round['rebuttal']['ai'] ?? '')}',
      );
      buffer.writeln(
        'Rebuttal (User): ${_sanitize(round['rebuttal']['user'] ?? '')}',
      );
      buffer.writeln(
        'Summary (Opponent): ${_sanitize(round['summary']['ai'] ?? '')}',
      );
      buffer.writeln(
        'Summary (User): ${_sanitize(round['summary']['user'] ?? '')}',
      );
      buffer.writeln(
        'Final Focus (Opponent): ${_sanitize(round['finalFocus']['ai'] ?? '')}',
      );
      buffer.writeln(
        'Final Focus (User): ${_sanitize(round['finalFocus']['user'] ?? '')}',
      );
      final judgeResult = round['judgeResult'];
      if (judgeResult != null) {
        buffer.writeln(
          'Judge Winner: ${judgeResult['winner']}  Score: ${judgeResult['persuasion_score']}',
        );
      }
    }
    return buffer.toString();
  }

  //✅ Judge Functions
  String _generateJudgePrompt() {
    final history = _debateHistory.isNotEmpty ? _buildHistoryContext() : '';
    return """
  You are a professional Public Forum Debate Judge. Evaluate the transcript and respond using EXACTLY the format below — no JSON, no markdown, just these labelled lines.
  There are several things to keep in mind when you judge a public forum debate round. First and foremost, the debater that wins should be the debater that persuaded you more. This can happen in many ways -- you might like their case better, you might think they gave an excellent final focus, or you might be overall more persuaded by their speaking style.
  The judge should write their reason for decision on the ballot. The judge will also give a explanation of their decision as well as areas of improvement to the students in the debate round.
  CRITERIA:
  1. Argumentation & Evidence
  2. Refutation
  3. Impact Calculus
  4. Consistency

  TRANSCRIPT:
  ${history.isNotEmpty ? 'PREVIOUS ROUNDS:\n$history\n' : ''}CURRENT ROUND TRANSCRIPT (Round $_roundNumber):
  Constructive (Opponent): ${_sanitize(_aiConstructiveText)}
  Constructive (User): ${_sanitize(_userConstructiveController.text)}
  Crossfire 1: ${_formatCrossfire(_crossfireMessages)}
  Rebuttal (Opponent): ${_sanitize(_aiRebuttalText)}
  Rebuttal (User): ${_sanitize(_userRebuttalController.text)}
  Crossfire 2: ${_formatCrossfire(_crossfireMessages2)}
  Summary (Opponent): ${_sanitize(_aiSummaryText)}
  Summary (User): ${_sanitize(_userSummaryController.text)}
  Crossfire 3: ${_formatCrossfire(_crossfireMessages3)}
  Final Focus (Opponent): ${_sanitize(_aiFinalFocusText)}
  Final Focus (User): ${_sanitize(_userFinalFocusController.text)}

  YOUR ENTIRE RESPONSE MUST BE ONLY THIS JSON, nothing before or after it:
  {
    "WINNER": (exactly "User" or "Opponent"),
    "SCORE": (0-100 integer, 50 = tie, below 50 = Opponent won, above 50 = User won),
    "reasoning": {
      "constructive_eval": (single sentence evaluation),
      "rebuttal_eval": (single sentence evaluation),
      "crossfire_eval": (single sentence evaluation),
      "voter_issues": (single sentence — the key reasons why the winner won)
    }
  }
""";
  }

  Future<void> _triggerJudge() async {
    setState(() => _isJudgeLoading = true);

    final prompt = _generateJudgePrompt();
    try {
      String raw = await _callGemini(prompt);

      raw = raw.replaceAll(RegExp(r'```json|```'), '').trim();

      raw = raw.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '');

      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(raw);
      if (jsonMatch == null)
        throw FormatException('No JSON object found in response');
      raw = jsonMatch.group(0)!;

      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final normalised = decoded.map((k, v) => MapEntry(k.toLowerCase(), v));

      final reasoning =
          (normalised['reasoning'] as Map<String, dynamic>?) ?? {};
      final rawVoterIssues = reasoning['voter_issues'];
      final voterIssuesStr =
          rawVoterIssues is List
              ? rawVoterIssues.join(' ')
              : rawVoterIssues?.toString() ?? '';

      setState(() {
        _judgeResult = {
          'winner': normalised['winner']?.toString() ?? 'Unknown',
          'persuasion_score':
              (normalised['score'] ?? normalised['persuasion_score'] ?? 50)
                  as num,
          'reasoning': {
            'constructive_eval':
                reasoning['constructive_eval']?.toString() ?? '',
            'rebuttal_eval': reasoning['rebuttal_eval']?.toString() ?? '',
            'crossfire_eval': reasoning['crossfire_eval']?.toString() ?? '',
            'voter_issues': voterIssuesStr,
          },
        };
        _isJudgeLoading = false;
      });
      _scrollToBottom();
    } catch (e) {
      setState(() => _isJudgeLoading = false);
      debugPrint("Judge Error: $e");
    }
  }

  Widget _buildJudgeUI() {
    if (_judgeResult == null) return const SizedBox();

    double score = (_judgeResult!['persuasion_score'] as num).toDouble();
    String winner = _judgeResult!['winner'];

    return Column(
      children: [
        const Divider(height: 50),
        Text(
          "OFFICIAL BALLOT",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        const SizedBox(height: 20),

        Container(
          height: 60,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(height: 4, color: Colors.grey.shade300),
              Positioned(
                left: (score / 100) * MediaQuery.of(context).size.width * 0.7,
                child: Column(
                  children: [
                    Icon(
                      Icons.location_on,
                      color: score > 50 ? Colors.green : Colors.red,
                    ),
                    Text(
                      "${score.toInt()}",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.blueAccent),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  "Winner: $winner",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Text(
                  _judgeResult!['reasoning']['voter_issues'],
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildArchivedRound(Map<String, dynamic> data) {
    final int roundNum = data['round'] as int;
    final String topic = data['topic'] as String;
    final constructive = data['constructive'] as Map<String, dynamic>;
    final rebuttal = data['rebuttal'] as Map<String, dynamic>;
    final summary = data['summary'] as Map<String, dynamic>;
    final finalFocus = data['finalFocus'] as Map<String, dynamic>;
    final List cf1 = data['crossfire_1'] as List;
    final List cf2 = data['crossfire_2'] as List;
    final List cf3 = data['crossfire_3'] as List;
    final judgeResult = data['judgeResult'] as Map<String, dynamic>?;

    Widget archivedBox(String title, String text, {bool isUser = false}) {
      return Container(
        constraints: const BoxConstraints(minHeight: 100),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color:
              isUser
                  ? const Color(0xFFC0C5CA).withOpacity(0.5)
                  : const Color(0xFFD9DEE3).withOpacity(0.5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              text,
              style: const TextStyle(fontSize: 12, color: Colors.black87),
            ),
          ],
        ),
      );
    }

    Widget archivedCrossfire(List msgs, String label) {
      if (msgs.isEmpty) return const SizedBox();
      return Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 255, 200, 191),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 8),
          ...msgs.map((m) {
            final bool isUser = m['isUser'] as bool;
            return Align(
              alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 3),
                padding: const EdgeInsets.all(10),
                constraints: const BoxConstraints(maxWidth: 400),
                decoration: BoxDecoration(
                  color:
                      isUser
                          ? const Color.fromARGB(255, 222, 218, 239)
                          : const Color.fromARGB(255, 205, 175, 197),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(10),
                    topRight: const Radius.circular(10),
                    bottomLeft:
                        isUser ? const Radius.circular(10) : Radius.zero,
                    bottomRight:
                        isUser ? Radius.zero : const Radius.circular(10),
                  ),
                ),
                child: Text(
                  m['text'] as String,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            );
          }),
        ],
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 40),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                "ROUND $roundNum",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  topic,
                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            "Completed",
            style: TextStyle(
              fontSize: 11,
              color: Colors.green,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Divider(height: 24),

          _buildArchivedSectionLabel(
            "Constructive Round",
            const Color.fromARGB(255, 191, 217, 255),
            const Color.fromARGB(255, 22, 77, 105),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: archivedBox("Opponent", constructive['ai'] as String),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: archivedBox(
                  "You",
                  constructive['user'] as String,
                  isUser: true,
                ),
              ),
            ],
          ),
          archivedCrossfire(cf1, "Crossfire 1"),

          const SizedBox(height: 16),
          _buildArchivedSectionLabel(
            "Rebuttal Round",
            const Color.fromARGB(255, 191, 217, 255),
            const Color.fromARGB(255, 22, 77, 105),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: archivedBox("Opponent", rebuttal['ai'] as String),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: archivedBox(
                  "You",
                  rebuttal['user'] as String,
                  isUser: true,
                ),
              ),
            ],
          ),
          archivedCrossfire(cf2, "Crossfire 2"),

          const SizedBox(height: 16),
          _buildArchivedSectionLabel(
            "Summary Round",
            const Color.fromARGB(255, 191, 217, 255),
            const Color.fromARGB(255, 22, 77, 105),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: archivedBox("Opponent", summary['ai'] as String)),
              const SizedBox(width: 16),
              Expanded(
                child: archivedBox(
                  "You",
                  summary['user'] as String,
                  isUser: true,
                ),
              ),
            ],
          ),
          archivedCrossfire(cf3, "Crossfire 3"),

          const SizedBox(height: 16),
          _buildArchivedSectionLabel(
            "Final Focus",
            const Color.fromARGB(255, 249, 197, 79),
            const Color.fromARGB(255, 14, 49, 130),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: archivedBox("Opponent", finalFocus['ai'] as String),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: archivedBox(
                  "You",
                  finalFocus['user'] as String,
                  isUser: true,
                ),
              ),
            ],
          ),

          if (judgeResult != null) ...[
            const Divider(height: 32),
            Center(
              child: Column(
                children: [
                  const Text(
                    "JUDGE VERDICT",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.blueAccent),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        Text(
                          "Winner: ${judgeResult['winner']}",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          judgeResult['reasoning']['voter_issues'] as String,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildArchivedSectionLabel(
    String label,
    Color bgColor,
    Color textColor,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildFinalActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          const Divider(),
          const SizedBox(height: 20),
          Text(
            "Round $_roundNumber Complete",
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 30),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "After this debate, how certain are you about your position?",
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                _buildGradientSlider(
                  _userFinalCertainty ?? 0,
                  (val) => setState(() {
                    _userFinalCertainty = val;
                    _isCertaintyAnswered = true;
                  }),
                ),
                if (!_isCertaintyAnswered) ...[
                  const Center(
                    child: Text(
                      "Please answer to continue",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.redAccent,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  onPressed:
                      _isCertaintyAnswered
                          ? () {
                            showDialog(
                              context: context,
                              builder:
                                  (ctx) => AlertDialog(
                                    title: const Text("Finish Debate?"),
                                    content: const Text(
                                      "All rounds will be saved and the debate will reset to the home screen.",
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx),
                                        child: const Text("Cancel"),
                                      ),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              Colors.blueGrey.shade800,
                                          foregroundColor: Colors.white,
                                        ),
                                        onPressed: () {
                                          Navigator.pop(ctx);
                                          _finishDebate();
                                        },
                                        child: const Text("Save & Finish"),
                                      ),
                                    ],
                                  ),
                            );
                          }
                          : null,
                  icon: const Icon(Icons.save_rounded, size: 18),
                  label: const Text(
                    "Finish Debate & Complete Survey Form",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _isCertaintyAnswered
                            ? Colors.blueGrey.shade800
                            : Colors.grey.shade400,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),

              SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isCertaintyAnswered ? _startNewRound : null,
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: Text(
                    "Start Round ${_roundNumber + 1}",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _isCertaintyAnswered
                            ? Colors.blue.shade700
                            : Colors.grey.shade400,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
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

  void _startNewRound() {
    _archiveCurrentRound();

    setState(() {
      _roundNumber++;

      _isAiGenerating = false;
      _aiConstructiveText = "";
      _userLetterCount = 0;

      _isCrossfireStarted = false;
      _isCrossfireStarted2 = false;
      _isCrossfireStarted3 = false;
      _secondsRemaining = 180;
      _crossfireMessages.clear();
      _crossfireMessages2.clear();
      _crossfireMessages3.clear();
      _isChatAiGenerating = false;

      _isRebuttalStarted = false;
      _isAiRebuttalGenerating = false;
      _hasStartedAiRebuttal = false;
      _aiRebuttalText = "";
      _userRebuttalLetterCount = 0;
      _isRebuttalSaved = false;

      _isSummaryStarted = false;
      _isAiSummaryGenerating = false;
      _hasStartedAiSummary = false;
      _aiSummaryText = "";
      _userSummaryLetterCount = 0;
      _isSummarySaved = false;

      _isFinalFocusStarted = false;
      _isAiFinalFocusGenerating = false;
      _hasStartedAiFinalFocus = false;
      _aiFinalFocusText = "";
      _userFinalFocusLetterCount = 0;
      _isFinalFocusSaved = false;

      _isJudgeLoading = false;
      _judgeResult = null;
      _isCertaintyAnswered = false;
      _userFinalCertainty = null;

      _userConstructiveController.clear();
      _userRebuttalController.clear();
      _userSummaryController.clear();
      _userFinalFocusController.clear();
    });

    _crossfireTimer?.cancel();

    _onStartDebate();

    Future.delayed(const Duration(milliseconds: 150), _scrollToBottom);
  }

  void _archiveCurrentRound() {
    _debateHistory.add({
      "round": _roundNumber,
      "topic": _selectedTopic,
      "oppSide": _oppSide,
      "persona": _persona,
      "constructive": {
        "user": _userConstructiveController.text,
        "ai": _aiConstructiveText,
      },
      "crossfire_1":
          _crossfireMessages
              .map((m) => {"isUser": m.isUser, "text": m.text})
              .toList(),
      "rebuttal": {"user": _userRebuttalController.text, "ai": _aiRebuttalText},
      "crossfire_2":
          _crossfireMessages2
              .map((m) => {"isUser": m.isUser, "text": m.text})
              .toList(),
      "summary": {"user": _userSummaryController.text, "ai": _aiSummaryText},
      "crossfire_3":
          _crossfireMessages3
              .map((m) => {"isUser": m.isUser, "text": m.text})
              .toList(),
      "finalFocus": {
        "user": _userFinalFocusController.text,
        "ai": _aiFinalFocusText,
      },
      "judgeResult": _judgeResult,
      "userFinalCertainty": _userFinalCertainty,
    });
  }

  void _finishDebate() async {
    _archiveCurrentRound();

    if (_isKakaoTalkBrowser()) {
      _showOpenInBrowserDialog();
      return;
    }

    final exportData = {
      "settings": {
        "topic": _selectedTopic,
        "oppSide": _oppSide,
        "persona": _persona,
        "oppCertainty": _oppCertainty,
        "userInitialCertainty": _userInitialCertainty,
        "userResearchCertainty": _userResearchCertainty,
      },
      "rounds": _debateHistory,
    };

    final String fullData = jsonEncode(exportData);
    final blob = html.Blob([fullData], 'application/json');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute(
        'download',
        'debate_history_${DateTime.now().millisecondsSinceEpoch}.json',
      )
      ..click();
    html.Url.revokeObjectUrl(url);

    html.window.open(
    'https://docs.google.com/forms/d/e/1FAIpQLSerBP2wHW9j8F-_sfplFcql_jD4MLRoWX1o2DsdVzJWG7PP9A/viewform',
    '_blank',
  );

    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text("Debate Finished"),
            content: Text(
              "All $_roundNumber round(s) have been saved.\nResetting to the home screen.",
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _resetEverything();
                },
                child: const Text("OK"),
              ),
            ],
          ),
    );
  }

  bool _isKakaoTalkBrowser() {
    final userAgent = html.window.navigator.userAgent.toLowerCase();
    return userAgent.contains('kakaotalk');
  }

  void _showOpenInBrowserDialog() {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text("Open in Browser"),
            content: const Text(
              "Downloads are not supported in KakaoTalk's browser.\n\nPlease tap the menu (⋮) and select 'Open in Browser' to download your files.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("OK"),
              ),
            ],
          ),
    );
  }

  void _resetEverything() {
    _crossfireTimer?.cancel();

    setState(() {
      _roundNumber = 1;
      _debateHistory.clear();

      _isDebateStarted = false;
      _isAiGenerating = false;
      _aiConstructiveText = "";
      _userLetterCount = 0;

      _isCrossfireStarted = false;
      _isCrossfireStarted2 = false;
      _isCrossfireStarted3 = false;
      _secondsRemaining = 180;
      _crossfireMessages.clear();
      _crossfireMessages2.clear();
      _crossfireMessages3.clear();
      _isChatAiGenerating = false;
      _isChatErrorFlash = false;

      _isRebuttalStarted = false;
      _isAiRebuttalGenerating = false;
      _hasStartedAiRebuttal = false;
      _aiRebuttalText = "";
      _userRebuttalLetterCount = 0;
      _isRebuttalSaved = false;

      _isSummaryStarted = false;
      _isAiSummaryGenerating = false;
      _hasStartedAiSummary = false;
      _aiSummaryText = "";
      _userSummaryLetterCount = 0;
      _isSummarySaved = false;

      _isFinalFocusStarted = false;
      _isAiFinalFocusGenerating = false;
      _hasStartedAiFinalFocus = false;
      _aiFinalFocusText = "";
      _userFinalFocusLetterCount = 0;
      _isFinalFocusSaved = false;

      _isJudgeLoading = false;
      _judgeResult = null;
      _isCertaintyAnswered = false;
      _userFinalCertainty = null;

      _oppCertainty = 20;
      _userInitialCertainty = 15;
      _userResearchCertainty = 15;
      _oppSide = 'pros';
      _persona = 'sympathetic';
      _selectedTopic = "None Selected";
      _subjectIntroduction = "Select or write a subject to start";
      _isCustomMode = false;
      _isSaveButtonError = false;

      _userConstructiveController.clear();
      _userRebuttalController.clear();
      _userSummaryController.clear();
      _userFinalFocusController.clear();
      _searchController.clear();
      _customSubjectController.clear();
      _chatInputController.clear();
      _filteredTopics = _allTopics;
    });
  }

  //✅ Main Page
  @override
  Widget build(BuildContext context) {
    List<String> sortedCategories = _filteredTopics.keys.toList()..sort();

    return Screenshot(
      controller: _screenshotController,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color.fromARGB(255, 238, 247, 252),
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.black),
          title: Text(
            _selectedTopic == "None Selected" || _selectedTopic.isEmpty
                ? "Debate Room"
                : _selectedTopic,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 255, 255, 255),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () => _showGuidePopup(context),
                child: const Text(
                  'Guide Book',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
        drawer: _isDebateStarted ? null : _buildDrawer(sortedCategories),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                controller: _chatScrollController,
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFBFBFB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade100),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Introduction",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _subjectIntroduction,
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                    if (!_isDebateStarted)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.only(top: 50),
                          child: Text(
                            "Configure your debate in the sidebar to begin.",
                          ),
                        ),
                      )
                    else ...[
                      ..._debateHistory.map(_buildArchivedRound),
                      ..._buildDebateRound(),
                    ],
                  ],
                ),
              ),
            ),
            if (_isCrossfireStarted) _buildChatInput(),
          ],
        ),
      ),
    );
  }

  //✅ Drawer Functions
  // Future<void> _captureWebScreenshot() async {
  //   final Uint8List? imageBytes = await _screenshotController.capture();
  //   if (_isKakaoTalkBrowser()) {
  //     _showOpenInBrowserDialog();
  //     return;
  //   }
  //   if (imageBytes != null) {
  //     final blob = html.Blob([imageBytes]);
  //     final url = html.Url.createObjectUrlFromBlob(blob);
  //     final anchor =
  //         html.AnchorElement(href: url)
  //           ..setAttribute("download", "debate_intro.png")
  //           ..click();
  //     html.Url.revokeObjectUrl(url);
  //   }
  // }

  Widget _buildDrawer(sortedCategories) {
    bool isTopicEmpty =
        _isCustomMode
            ? _customSubjectController.text.trim().isEmpty
            : _searchController.text.trim().isEmpty;

    return Drawer(
      width: 420,
      backgroundColor: const Color(0xFFF5F5F5),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('Topic'),

              Row(
                children: [
                  Expanded(
                    child: TextField(
                      enabled: !_isCustomMode,
                      controller: _searchController,
                      onChanged: _filterSearch,
                      decoration: InputDecoration(
                        hintText: 'Search topics...',
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor:
                            !_isCustomMode
                                ? Colors.white
                                : Colors.grey.shade200,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  Radio<bool>(
                    value: false,
                    groupValue: _isCustomMode,
                    onChanged: (v) => setState(() => _isCustomMode = v!),
                  ),
                ],
              ),

              if (!_isCustomMode)
                Container(
                  height: 250,
                  margin: const EdgeInsets.only(top: 10, right: 48),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(color: Colors.black12, blurRadius: 4),
                    ],
                  ),
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      scrollbarTheme: ScrollbarThemeData(
                        thumbVisibility: WidgetStateProperty.all(true),
                        thickness: WidgetStateProperty.all(6),
                        thumbColor: WidgetStateProperty.all(
                          Colors.grey.shade400,
                        ),
                        radius: const Radius.circular(10),
                      ),
                    ),
                    child: Scrollbar(
                      thumbVisibility: true,
                      controller: _categoryScrollController,
                      child: ListView.builder(
                        controller: _categoryScrollController,
                        padding: const EdgeInsets.only(right: 12),
                        itemCount: sortedCategories.length,
                        itemBuilder: (context, index) {
                          String category = sortedCategories[index];
                          String firstLetter = category[0].toUpperCase();
                          bool showLetter =
                              index == 0 ||
                              sortedCategories[index - 1][0].toUpperCase() !=
                                  firstLetter;

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 35,
                                padding: const EdgeInsets.only(
                                  top: 16,
                                  left: 10,
                                ),
                                child: Text(
                                  showLetter ? firstLetter : "",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey.shade400,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: ExpansionTile(
                                  key: PageStorageKey(category),
                                  shape: const Border(),
                                  title: Text(
                                    category,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  children:
                                      _filteredTopics[category]!.map((topic) {
                                        return ListTile(
                                          title: Text(
                                            topic,
                                            style: const TextStyle(
                                              fontSize: 13,
                                            ),
                                          ),
                                          onTap: () {
                                            setState(() {
                                              _selectedTopic = topic;
                                              _searchController.text = topic;
                                            });
                                          },
                                        );
                                      }).toList(),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: TextField(
                      enabled: _isCustomMode,
                      controller: _customSubjectController,
                      onSubmitted: (value) {
                        if (value.trim().isNotEmpty) {
                          setState(() => _selectedTopic = value);
                        }
                      },
                      decoration: InputDecoration(
                        hintText: 'Enter your custom topic...',
                        filled: true,
                        fillColor:
                            _isCustomMode ? Colors.white : Colors.grey.shade200,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  Radio<bool>(
                    value: true,
                    groupValue: _isCustomMode,
                    onChanged: (v) => setState(() => _isCustomMode = v!),
                  ),
                ],
              ),

              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10.0),
                child: Divider(thickness: 1, color: Colors.blueGrey),
              ),

              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(child: _buildSectionHeader('Opponent settings')),

                  InkWell(
                    onTap: () => setState(() => _oppSide = 'pros'),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('pros', style: TextStyle(fontSize: 14)),
                        Radio<String>(
                          value: 'pros',
                          groupValue: _oppSide,
                          onChanged: (v) => setState(() => _oppSide = v!),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 12),
                  InkWell(
                    onTap: () => setState(() => _oppSide = 'cons'),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('cons', style: TextStyle(fontSize: 14)),
                        Radio<String>(
                          value: 'cons',
                          groupValue: _oppSide,
                          onChanged: (v) => setState(() => _oppSide = v!),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 15),
              Wrap(
                spacing: 8,
                children:
                    ['Dogmatic', 'Analytical', 'Open-Minded'].map((p) {
                      bool isSelected = _persona == p;
                      return ChoiceChip(
                        showCheckmark: false,

                        label: Text(p),
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.normal,
                          color: Colors.black,
                        ),

                        selected: isSelected,
                        onSelected: (selected) => setState(() => _persona = p),

                        backgroundColor: Colors.white,
                        selectedColor: Colors.grey.shade300,
                        side: BorderSide(
                          color:
                              isSelected
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade300,
                          width: 1,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      );
                    }).toList(),
              ),

              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10.0),
                child: Divider(thickness: 1, color: Colors.blueGrey),
              ),

              const SizedBox(height: 10),
              _buildSectionHeader('User survey'),
              _buildSliderLabel('Degree of certainty', _userInitialCertainty),
              const SizedBox(height: 16),
              _buildGradientSlider(
                _userInitialCertainty,
                (v) => setState(() => _userInitialCertainty = v),
              ),

              const SizedBox(height: 8),
              _buildSliderLabel(
                'Degree of certainty after research',
                _userResearchCertainty,
              ),
              const SizedBox(height: 20),
              _buildGradientSlider(
                _userResearchCertainty,
                (v) => setState(() => _userResearchCertainty = v),
              ),

              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10.0),
                child: Divider(thickness: 1, color: Colors.blueGrey),
              ),

              const SizedBox(height: 10),
              _buildSectionHeader('Reason for topic choice'),
              ..._subjectChoices.keys.map((key) {
                bool isOther = key == 'other';

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CheckboxListTile(
                      title: Text(key, style: const TextStyle(fontSize: 14)),
                      value: _subjectChoices[key],
                      onChanged:
                          (v) => setState(() => _subjectChoices[key] = v!),
                      controlAffinity: ListTileControlAffinity.trailing,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                    if (isOther && _subjectChoices['other'] == true)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10.0),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              TextField(
                                controller: _otherController,
                                maxLength: 200,
                                maxLines: 5,
                                style: const TextStyle(fontSize: 13),
                                decoration: const InputDecoration(
                                  hintText: 'Please specify...',
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                  border: InputBorder.none,
                                  counterText: "",
                                ),
                                onChanged: (v) => setState(() {}),
                              ),
                              Text(
                                '${_otherController.text.length}/200',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              }).toList(),

              const SizedBox(height: 10),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        isTopicEmpty ? Colors.redAccent : Colors.blue.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  onPressed: () async {
                    String finalTopic =
                        _isCustomMode
                            ? _customSubjectController.text.trim()
                            : _searchController.text.trim();

                    if (finalTopic.isNotEmpty) {
                      setState(() => _selectedTopic = finalTopic);
                      Navigator.pop(context);
                      // await _captureWebScreenshot();
                      await Future.delayed(const Duration(milliseconds: 300));
                      _generateIntroduction(finalTopic);
                      _onStartDebate();
                    } else {
                      setState(() {});
                    }
                  },
                  child: Text(
                    isTopicEmpty ? 'Choose Topic' : 'Start Debate',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        title,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildSliderLabel(String label, double value) {
    return Text(
      label,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
    );
  }

  Widget _buildGradientSlider(double value, ValueChanged<double> onChanged) {
    return LayoutBuilder(
      builder: (context, constraints) {
        double percent = value / 100.0;
        const double leftLabelWidth = 30.0;
        const double rightLabelWidth = 40.0;
        const double gap = 12.0;

        double availableWidth =
            constraints.maxWidth - leftLabelWidth - rightLabelWidth - (gap * 2);
        double labelOffset = (availableWidth * percent) - 20;

        return Column(
          children: [
            Row(
              children: [
                const SizedBox(
                  width: leftLabelWidth,
                  child: Text('0', style: TextStyle(fontSize: 10)),
                ),
                const SizedBox(width: gap),
                Expanded(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        height: 14,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          gradient: const LinearGradient(
                            colors: [
                              Colors.greenAccent,
                              Colors.yellow,
                              Colors.orange,
                              Colors.red,
                              Colors.purple,
                            ],
                          ),
                        ),
                      ),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 14,
                          trackShape: FullWidthTrackShape(),
                          activeTrackColor: Colors.transparent,
                          inactiveTrackColor: Colors.transparent,
                          thumbColor: Colors.white,
                          overlayShape: SliderComponentShape.noOverlay,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 8,
                            elevation: 3,
                          ),
                        ),
                        child: Slider(
                          value: value,
                          min: 0,
                          max: 100,
                          onChanged: onChanged,
                        ),
                      ),
                      Positioned(
                        bottom: -25,
                        left: labelOffset,
                        child: SizedBox(
                          width: 40,
                          child: Text(
                            value.toInt().toString(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: gap),
                const SizedBox(
                  width: rightLabelWidth,
                  child: Text('100', style: TextStyle(fontSize: 10)),
                ),
              ],
            ),
            const SizedBox(height: 25),
          ],
        );
      },
    );
  }
}
