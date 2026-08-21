(function () {
  const CACHE_PREFIX = "gh_cache_";
  const CACHE_TTL_MS = 10 * 60 * 1000; // 10 minutes cache in sessionStorage

  function getCached(key) {
    try {
      const item = sessionStorage.getItem(CACHE_PREFIX + key);
      if (!item) return null;
      const parsed = JSON.parse(item);
      if (Date.now() - parsed.timestamp < CACHE_TTL_MS) {
        return parsed.data;
      }
      sessionStorage.removeItem(CACHE_PREFIX + key);
    } catch (e) {
      // Ignore storage quota / access errors
    }
    return null;
  }

  function setCached(key, data) {
    try {
      sessionStorage.setItem(
        CACHE_PREFIX + key,
        JSON.stringify({
          data: data,
          timestamp: Date.now(),
        })
      );
    } catch (e) {
      // Ignore storage quota / access errors
    }
  }

  async function fetchRepoData(repoName) {
    const cached = getCached("repo_" + repoName);
    if (cached) return cached;

    try {
      const res = await fetch(`https://api.github.com/repos/${repoName}`);
      if (!res.ok) return null;
      const data = await res.json();
      setCached("repo_" + repoName, data);
      return data;
    } catch (err) {
      return null;
    }
  }

  async function fetchUserData(username) {
    const cached = getCached("user_" + username);
    if (cached) return cached;

    try {
      const res = await fetch(`https://api.github.com/users/${username}`);
      if (!res.ok) return null;
      const data = await res.json();
      setCached("user_" + username, data);
      return data;
    } catch (err) {
      return null;
    }
  }

  function initDynamicGitHub() {
    // 1. Dynamic update for GitHub Repositories
    const repoCards = document.querySelectorAll("[data-github-repo]");
    repoCards.forEach(async (card) => {
      const repoName = card.getAttribute("data-github-repo");
      if (!repoName) return;

      const data = await fetchRepoData(repoName);
      if (!data) return;

      if (data.stargazers_count !== undefined) {
        const starsEl = card.querySelector(".js-repo-stars");
        if (starsEl) {
          starsEl.textContent = `Stars: ${data.stargazers_count}`;
        }
      }

      if (data.forks_count !== undefined) {
        const forksEl = card.querySelector(".js-repo-forks");
        if (forksEl) {
          forksEl.textContent = `Forks: ${data.forks_count}`;
        }
      }

      if (data.language) {
        const langEl = card.querySelector(".js-repo-lang");
        if (langEl) {
          langEl.textContent = `Language: ${data.language}`;
        }
      }

      if (data.description) {
        const descEl = card.querySelector(".js-repo-desc");
        if (descEl) {
          descEl.textContent = data.description;
        }
      }
    });

    // 2. Dynamic update for GitHub Users
    const userCards = document.querySelectorAll("[data-github-user]");
    userCards.forEach(async (card) => {
      const username = card.getAttribute("data-github-user");
      if (!username) return;

      const data = await fetchUserData(username);
      if (!data) return;

      if (data.name) {
        const nameEl = card.querySelector(".js-user-name");
        if (nameEl) {
          nameEl.textContent = data.name;
        }
      }

      if (data.avatar_url) {
        const avatarEl = card.querySelector(".js-user-avatar");
        if (avatarEl) {
          avatarEl.src = data.avatar_url;
        }
      }
    });
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", initDynamicGitHub);
  } else {
    initDynamicGitHub();
  }
})();
