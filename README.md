# Magithub

[![MELPA Status](http://melpa.milkbox.net/packages/magithub-badge.svg)](http://melpa.milkbox.net/#/magithub)
[![MELPA Stable Status](http://melpa-stable.milkbox.net/packages/magithub-badge.svg)](http://melpa-stable.milkbox.net/#/magithub)

Magithub is a collection of interfaces to GitHub.

Integrated into [Magit][magit] workflows, Magithub allows very easy,
very basic GitHub repository management.  Supported actions from the
status buffer include:

 - pushing brand-new local repositories up to GitHub (`h c`)
 - creating forks of existing repositories (`h f`)
 - submitting pull requests upstream (`h p`)
 - creating issues (`h i`)

Happy hacking!

## Installation

The package can be installed from MELPA.  Otherwise, simply place
`magithub.el` in your `load-path` and `(require 'magithub)`.

If you use [use-package][gh-use-package], you should instead alter
your `magit` form to `(use-package magithub)`:

```elisp
(use-package magit
  :config (use-package magithub))
```

For now, Magithub requires the `hub` utility to work -- before trying
to use Magithub, follow the installation instructions
at [hub.github.com][hub].  To force `hub` to authenticate, you can use
`hub browse` in a terminal (inside a GitHub repo).

## Screenshots

### Creating a Repository

![Creating](images/create.gif)

### Submitting a Pull Request

![Creating](images/pull-request.gif)

---

![Dispatch](images/scr1.png)|![Creating](images/scr2.png)
:-------------------------:|:-------------------------:
![Forking](images/scr3.png)|![Pushing](images/scr4.png)

### Note

There used to be another `magithub`: [nex3/magithub][old-magithub].
It's long-since unsupported and apparently has many issues
(see [nex3/magithub#11][old-magithub-11]
and [nex3/magithub#13][old-magithub-13]) and
was [removed from MELPA][melpa-1126] some years ago.  If you have it
installed or configured, you may wish to remove/archive that
configuration to avoid name-clash issues.  Given that the package has
been defunct for over three years and is likely abandoned, the present
package's name will not be changing.

[magit]: //www.github.com/magit/magit
[hub]: //hub.github.com
[gh-use-package]: //github.com/jwiegley/use-package
[old-magithub]: //github.com/nex3/magithub
[old-magithub-11]: //github.com/nex3/magithub/issues/11
[old-magithub-13]: //github.com/nex3/magithub/issues/13
[melpa-1126]: //github.com/melpa/melpa/issues/1126
