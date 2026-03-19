const admin = require("firebase-admin");
const {onDocumentWritten} = require("firebase-functions/v2/firestore");
const {onSchedule} = require("firebase-functions/v2/scheduler");

admin.initializeApp();
const db = admin.firestore();

exports.aggregateSubmissionVotes = onDocumentWritten(
  "community_submissions/{submissionId}/votes/{uid}",
  async (event) => {
    const submissionId = event.params.submissionId;
    const votesSnap = await db
      .collection("community_submissions")
      .doc(submissionId)
      .collection("votes")
      .get();

    let upvotes = 0;
    let downvotes = 0;
    votesSnap.docs.forEach((d) => {
      const v = d.data().vote;
      if (v === 1) upvotes += 1;
      if (v === -1) downvotes += 1;
    });

    await db.collection("community_submissions").doc(submissionId).set(
      {
        upvotes,
        downvotes,
        score: upvotes - downvotes,
        scoreUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      {merge: true}
    );
  }
);

exports.normalizeSubmission = onDocumentWritten(
  "community_submissions/{submissionId}",
  async (event) => {
    if (!event.data || !event.data.after.exists) return;
    const after = event.data.after.data();
    const term = (after.term || "").toString().trim();
    if (!term) return;
    await event.data.after.ref.set(
      {
        termLower: term.toLowerCase(),
      },
      {merge: true}
    );
  }
);

exports.resetWeeklySeasonStats = onSchedule(
  {
    schedule: "every monday 00:00",
    timeZone: "America/Chicago",
  },
  async () => {
    const users = await db.collection("users").get();
    const batch = db.batch();
    users.docs.forEach((doc) => {
      batch.set(
        doc.ref,
        {
          weeklyXp: 0,
          seasonUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        {merge: true}
      );
    });
    await batch.commit();
  }
);

exports.aggregateCityTrends = onSchedule(
  {
    schedule: "every 24 hours",
    timeZone: "America/Chicago",
  },
  async () => {
    const since = admin.firestore.Timestamp.fromDate(
      new Date(Date.now() - 1000 * 60 * 60 * 24 * 7)
    );
    const docs = await db
      .collection("community_submissions")
      .where("status", "==", "approved")
      .where("createdAt", ">=", since)
      .get();

    const cityBuckets = new Map();
    docs.docs.forEach((d) => {
      const data = d.data();
      const city = (data.city || "global").toString().trim().toLowerCase();
      const term = (data.term || "").toString().trim().toLowerCase();
      if (!term) return;
      if (!cityBuckets.has(city)) cityBuckets.set(city, new Map());
      const terms = cityBuckets.get(city);
      terms.set(term, (terms.get(term) || 0) + 1);
    });

    const now = new Date();
    const key = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(
      2,
      "0"
    )}-${String(now.getDate()).padStart(2, "0")}`;

    const writes = [];
    for (const [city, map] of cityBuckets.entries()) {
      const topTerms = [...map.entries()]
        .sort((a, b) => b[1] - a[1])
        .slice(0, 25)
        .map(([term, count]) => ({term, count}));

      writes.push(
        db
          .collection("city_trends")
          .doc(city)
          .collection("daily")
          .doc(key)
          .set(
            {
              terms: topTerms,
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            },
            {merge: true}
          )
      );
    }
    await Promise.all(writes);
  }
);
