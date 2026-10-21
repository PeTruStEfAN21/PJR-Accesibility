# PJR-Accesibility

## Claude Code

Proiectul activează două pluginuri prin `.claude/settings.json`:

- [Superpowers](https://github.com/obra/superpowers): brainstorming, planuri, TDD, debugging, code review
- [UI UX Pro Max](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill): stiluri, palete, fonturi și reguli de UI/UX (necesită Python 3)

După `git pull`, pornește `claude` în folderul proiectului și acceptă marketplace-ul și pluginurile când ești întrebat.

Dacă nu apare promptul, instalează manual:

```
/plugin install superpowers@claude-plugins-official
/plugin marketplace add nextlevelbuilder/ui-ux-pro-max-skill
/plugin install ui-ux-pro-max@ui-ux-pro-max-skill
```
