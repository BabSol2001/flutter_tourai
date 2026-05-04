/// یک مدل داده‌ای عمومی برای هر مرحله از ویرایش
class EditStep<T> {
  final String label;
  final T state; // این می‌تواند شامل Map تنظیمات یا هر شیء دیگری باشد
  final DateTime timestamp;

  EditStep(this.label, this.state) : timestamp = DateTime.now();
}

class EditHistoryManager<T> {
  List<EditStep<T>> _history = [];
  int _currentIndex = -1;
  int _lastSavedIndex = -1;

  /// مقداردهی اولیه با وضعیت اصلی
  void initialize(String label, T initialState) {
    _history = [EditStep(label, initialState)];
    _currentIndex = 0;
    _lastSavedIndex = 0;
  }

  /// اضافه کردن مرحله جدید و مدیریت انشعاب (Branching)
  void addStep(String label, T newState) {
    // اگر کاربر Undo کرده بود و تغییر جدید داد، مراحل آینده پاک می‌شوند
    if (_currentIndex < _history.length - 1) {
      _history = _history.sublist(0, _currentIndex + 1);
    }
    
    _history.add(EditStep(label, newState));
    _currentIndex++;
  }

  /// عملیات Undo
  EditStep<T>? undo() {
    if (canUndo) {
      _currentIndex--;
      return currentStep;
    }
    return null;
  }

  /// عملیات Redo
  EditStep<T>? redo() {
    if (canRedo) {
      _currentIndex++;
      return currentStep;
    }
    return null;
  }

  /// پرش به یک مرحله خاص
  void goToStep(int index) {
    if (index >= 0 && index < _history.length) {
      _currentIndex = index;
    }
  }

  /// ثبت وضعیت فعلی به عنوان وضعیت ذخیره شده نهایی
  void markAsSaved() {
    _lastSavedIndex = _currentIndex;
  }

  // --- Getters برای استفاده در UI ---

  bool get canUndo => _currentIndex > 0;
  
  bool get canRedo => _currentIndex < _history.length - 1;
  
  /// آیا مرحله‌ای که کاربر الان می‌بیند، همان مرحله ذخیره شده است؟
  bool get isCurrentStepSaved => (_currentIndex != -1) && (_currentIndex == _lastSavedIndex);
  
  /// دسترسی به اسنپ‌شات مرحله فعلی
  EditStep<T> get currentStep => _history[_currentIndex];
  
  /// لیست تمام مراحل برای نمایش در نوار تاریخچه
  List<EditStep<T>> get allSteps => List.unmodifiable(_history);
  
  int get currentIndex => _currentIndex;
  
  int get lastSavedIndex => _lastSavedIndex;
}