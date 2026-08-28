// Every user-facing string in one place, so voice can be audited and
// changed in one pass. Register: professional, direct, no em-dashes, no
// gamified language on the educator side.

export const S = {
  errors: {
    generic: 'Something went wrong on our side. Try again.',
    sessionExpired: 'Your session expired. Sign in again to continue.',
    offline: 'You appear to be offline. Check your connection and try again.',
    aggregateOnly:
      'This class reports aggregate data only, so per-student views are off.',
    notFaculty: 'Your account does not have faculty access to this class.',
    badSessionCode:
      'That code does not match a running session. Check it with your instructor.',
    displayName: 'Enter a display name between 2 and 40 characters.',
    membersOnly:
      'This session is limited to class members. Join the class in the app first.',
    questionClosed: 'That question just closed.',
    timeUp: 'Time is up for this question.',
    noAccount:
      'No Politiface account uses that email. They need to sign in to the app or console once first.',
    needsInvite: 'That account has not redeemed a faculty invite code yet.',
    needsVerification:
      'Creating classes requires instructor verification. Redeem a faculty invite code in the app or portal first.',
    classNameShort: 'Class names need at least 3 characters.',
    somethingBroke:
      'This view hit an unexpected error. Reload the page; your data is safe.',
  },
  empty: {
    classesTitle: 'No classes yet',
    classesHint:
      'Create your first class below. Students join it from the Politiface app with the class code.',
    studentsTitle: 'No students yet',
    studentsHint:
      'Share the class join code and students appear here as they enroll.',
    sessionsTitle: 'No live sessions yet',
    sessionsHint:
      'Run a session and students join from any browser with a code.',
    atRiskAllClear: 'No students yet.',
  },
  common: {
    exportCsv: 'Export CSV',
    exportStudentsCsv: 'Export students CSV',
    exportClassCsv: 'Export class CSV',
    signOut: 'Sign out',
    reload: 'Reload',
    cancel: 'Cancel',
    save: 'Save',
    loading: 'Loading',
    backToClass: 'Back to class',
    yourClasses: 'Your classes',
    createClass: 'Create a class',
  },
  policy: {
    perStudent: 'This class reports per-student detail to faculty.',
    pseudonymous: 'Students appear under stable pseudonyms, never names.',
    aggregateOnly: 'This class reports aggregate data only.',
  },
  pulse: {
    seeWho: 'See who',
    reteach: 'Run a reteach session',
    message: 'Message the class',
  },
  assignment: {
    assigned:
      'Practice assigned and announced to the class. Retention checks run automatically at 7 and 21 days.',
  },
  provenance: {
    verified: 'Server-verified',
  },
} as const
