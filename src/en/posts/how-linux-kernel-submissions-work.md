---
title: "LKD - #5 Notes on how the linux patch submission works"
date: 2026-04-12
layout: layouts/post.njk
language: en
place: brazil
description:
  "A summarized version of how change revisions work at the linux kernel, how to
  send patch emails with git and how to see linux threads."
tags:
  - linux
  - kernel development
  - MAC0470
  - MAC5856
  - USP
  - open source software
  - mailing list
  - patch
---

As part of my classes on [Open Source Software (OSS)](https://opensource.org/)
my whole class is starting to work on Linux Kernel Development. This post is a
series of my experiences throughout the class related to kernel development.
This post is a follow-up of
[this previous post](/posts/intro-linuxkernelbuildconfigandmodules) and part of
[this series](/posts/tag/MAC5856).

> **Note:** This post is a companion to the
> [Sending patches by email with git](https://flusp.ime.usp.br/git/sending-patches-by-email-with-git/)
> and
> [Sending patches with git and USP email](https://flusp.ime.usp.br/git/sending-patches-with-git-and-a-usp-email/)
> tutorial from FLUSP. For specifically this post, you don't need to check the
> companion ones unless you want.

In the last post we created and deployed a custom module to our VM. In this post
we will talk about how patch submissions work and how to submit a patch by email
with git

## How changes are reviewed in the Linux Kernel?

If you're familiar with modern software development chances are you are probably
used to tools like github, gitlab or bitbucket which offers some of submitting
your changes to a peer review to be: tested, commented, approved and merged into
some stable branch. This way of reviewing changes is a modernized version of the
Linux process. Linux predates all of the tools which offer this type of
revision, Linux changes are actually submitted and reviewed using git patches
sent by e-mail.

All of the changes made in the kernel are actually kept public in the
[lore](https://lore.kernel.org/), so you can actually see what a code submission
looks like, one patch example is
[this one](https://lore.kernel.org/all/20260418043837.721045-1-ricardo.kojo@ime.usp.br/):

```
Use guard() and scoped_guard() for handling mutex and spin locks instead of
manually locking and unlocking. This prevents forgotten locks due to early
exits and remove the need of gotos.

Signed-off-by: Ricardo H H Kojo <ricardo.kojo@ime.usp.br>
Co-developed-by: Ellian Carlos <elliancarlos@gmail.com>
Signed-off-by: Ellian Carlos <elliancarlos@gmail.com>
Co-developed-by: Gabriel B L de Oliveira <gabrielblo@ime.usp.br>
Signed-off-by: Gabriel B L de Oliveira <gabrielblo@ime.usp.br>
---
 drivers/block/null_blk/main.c     | 74 +++++++++++++------------------
 drivers/block/null_blk/null_blk.h |  1 +
 2 files changed, 32 insertions(+), 43 deletions(-)

diff --git a/drivers/block/null_blk/main.c b/drivers/block/null_blk/main.c
index f8c0fd57e041..fbe34e8a6c93 100644
--- a/drivers/block/null_blk/main.c
+++ b/drivers/block/null_blk/main.c
@@ -423,9 +423,8 @@ static int nullb_apply_submit_queues(struct nullb_device *dev,
 {
        int ret;

-       mutex_lock(&lock);
+       guard(mutex)(&lock);
        ret = nullb_update_nr_hw_queues(dev, submit_queues, dev->poll_queues);
-       mutex_unlock(&lock);

        return ret;
 }
@@ -435,9 +434,8 @@ static int nullb_apply_poll_queues(struct nullb_device *dev,
 {
        int ret;

-       mutex_lock(&lock);
+       guard(mutex)(&lock);
        ret = nullb_update_nr_hw_queues(dev, dev->submit_queues, poll_queues);
-       mutex_unlock(&lock);

        return ret;
 }
@@ -493,15 +491,15 @@ static ssize_t nullb_device_power_store(struct config_item *item,
                return ret;

        ret = count;
-       mutex_lock(&lock);
+       guard(mutex)(&lock);
        if (!dev->power && newp) {
                if (test_and_set_bit(NULLB_DEV_FL_UP, &dev->flags))
-                       goto out;
+                       return ret;

                ret = null_add_dev(dev);
                if (ret) {
                        clear_bit(NULLB_DEV_FL_UP, &dev->flags);
-                       goto out;
+                       return ret;
                }

                set_bit(NULLB_DEV_FL_CONFIGURED, &dev->flags);
@@ -515,8 +513,6 @@ static ssize_t nullb_device_power_store(struct config_item *item,
                clear_bit(NULLB_DEV_FL_CONFIGURED, &dev->flags);
        }

-out:
-       mutex_unlock(&lock);
        return ret;
 }

@@ -707,10 +703,9 @@ nullb_group_drop_item(struct config_group *group, struct config_item *item)
        struct nullb_device *dev = to_nullb_device(item);

        if (test_and_clear_bit(NULLB_DEV_FL_UP, &dev->flags)) {
-               mutex_lock(&lock);
+               guard(mutex)(&lock);
                dev->power = false;
                null_del_dev(dev->nullb);
-               mutex_unlock(&lock);
        }
        nullb_del_fault_config(dev);
        config_item_put(item);
@@ -1205,7 +1200,7 @@ blk_status_t null_handle_discard(struct nullb_device *dev,
        size_t n = nr_sectors << SECTOR_SHIFT;
        size_t temp;

-       spin_lock_irq(&nullb->lock);
+       guard(spinlock_irq)(&nullb->lock);
        while (n > 0) {
                temp = min_t(size_t, n, dev->blocksize);
                null_free_sector(nullb, sector, false);
@@ -1214,7 +1209,6 @@ blk_status_t null_handle_discard(struct nullb_device *dev,
                sector += temp >> SECTOR_SHIFT;
                n -= temp;
        }
-       spin_unlock_irq(&nullb->lock);

        return BLK_STS_OK;
 }
@@ -1226,7 +1220,7 @@ static blk_status_t null_handle_flush(struct nullb *nullb)
        if (!null_cache_active(nullb))
                return 0;

-       spin_lock_irq(&nullb->lock);
+       guard(spinlock_irq)(&nullb->lock);
        while (true) {
                err = null_make_cache_space(nullb,
                        nullb->dev->cache_size * 1024 * 1024);
@@ -1235,7 +1229,6 @@ static blk_status_t null_handle_flush(struct nullb *nullb)
        }

        WARN_ON(!radix_tree_empty(&nullb->dev->cache));
-       spin_unlock_irq(&nullb->lock);
        return errno_to_blk_status(err);
 }

@@ -1292,7 +1285,7 @@ static blk_status_t null_handle_data_transfer(struct nullb_cmd *cmd,
        struct req_iterator iter;
        struct bio_vec bvec;

-       spin_lock_irq(&nullb->lock);
+       guard(spinlock_irq)(&nullb->lock);
        rq_for_each_segment(bvec, rq, iter) {
                len = bvec.bv_len;
                if (transferred_bytes + len > max_bytes)
@@ -1307,7 +1300,6 @@ static blk_status_t null_handle_data_transfer(struct nullb_cmd *cmd,
                if (transferred_bytes >= max_bytes)
                        break;
        }
-       spin_unlock_irq(&nullb->lock);

        return err;
 }
@@ -1592,11 +1584,11 @@ static int null_poll(struct blk_mq_hw_ctx *hctx, struct io_comp_batch *iob)
        int nr = 0;
        struct request *rq;

-       spin_lock(&nq->poll_lock);
-       list_splice_init(&nq->poll_list, &list);
-       list_for_each_entry(rq, &list, queuelist)
-               blk_mq_set_request_complete(rq);
-       spin_unlock(&nq->poll_lock);
+       scoped_guard(spinlock, &nq->poll_lock) {
+               list_splice_init(&nq->poll_list, &list);
+               list_for_each_entry(rq, &list, queuelist)
+                       blk_mq_set_request_complete(rq);
+       }

        while (!list_empty(&list)) {
                struct nullb_cmd *cmd;
@@ -1624,14 +1616,12 @@ static enum blk_eh_timer_return null_timeout_rq(struct request *rq)
        if (hctx->type == HCTX_TYPE_POLL) {
                struct nullb_queue *nq = hctx->driver_data;

-               spin_lock(&nq->poll_lock);
-               /* The request may have completed meanwhile. */
-               if (blk_mq_request_completed(rq)) {
-                       spin_unlock(&nq->poll_lock);
-                       return BLK_EH_DONE;
+               scoped_guard(spinlock, &nq->poll_lock) {
+                       /* The request may have completed meanwhile. */
+                       if (blk_mq_request_completed(rq))
+                               return BLK_EH_DONE;
+                       list_del_init(&rq->queuelist);
                }
-               list_del_init(&rq->queuelist);
-               spin_unlock(&nq->poll_lock);
        }

        pr_info("rq %p timed out\n", rq);
@@ -1692,9 +1682,9 @@ static blk_status_t null_queue_rq(struct blk_mq_hw_ctx *hctx,
        blk_mq_start_request(rq);

        if (is_poll) {
-               spin_lock(&nq->poll_lock);
-               list_add_tail(&rq->queuelist, &nq->poll_list);
-               spin_unlock(&nq->poll_lock);
+               scoped_guard(spinlock, &nq->poll_lock) {
+                       list_add_tail(&rq->queuelist, &nq->poll_list);
+               }
                return BLK_STS_OK;
        }
        if (cmd->fake_timeout)
@@ -2081,14 +2071,13 @@ static struct nullb *null_find_dev_by_name(const char *name)
 {
        struct nullb *nullb = NULL, *nb;

-       mutex_lock(&lock);
+       guard(mutex)(&lock);
        list_for_each_entry(nb, &nullb_list, list) {
                if (strcmp(nb->disk_name, name) == 0) {
                        nullb = nb;
                        break;
                }
        }
-       mutex_unlock(&lock);

        return nullb;
 }
@@ -2101,10 +2090,9 @@ static int null_create_dev(void)
        dev = null_alloc_dev();
        if (!dev)
                return -ENOMEM;
-
-       mutex_lock(&lock);
-       ret = null_add_dev(dev);
-       mutex_unlock(&lock);
+       scoped_guard(mutex, &lock) {
+               ret = null_add_dev(dev);
+       }
        if (ret) {
                null_free_dev(dev);
                return ret;
@@ -2202,12 +2190,12 @@ static void __exit null_exit(void)

        unregister_blkdev(null_major, "nullb");

-       mutex_lock(&lock);
-       while (!list_empty(&nullb_list)) {
-               nullb = list_entry(nullb_list.next, struct nullb, list);
-               null_destroy_dev(nullb);
+       scoped_guard(mutex, &lock) {
+               while (!list_empty(&nullb_list)) {
+                       nullb = list_entry(nullb_list.next, struct nullb, list);
+                       null_destroy_dev(nullb);
+               }
        }
-       mutex_unlock(&lock);

        if (tag_set.ops)
                blk_mq_free_tag_set(&tag_set);
diff --git a/drivers/block/null_blk/null_blk.h b/drivers/block/null_blk/null_blk.h
index 6c4c4bbe7dad..c2bb085d3582 100644
--- a/drivers/block/null_blk/null_blk.h
+++ b/drivers/block/null_blk/null_blk.h
@@ -14,6 +14,7 @@
 #include <linux/fault-inject.h>
 #include <linux/spinlock.h>
 #include <linux/mutex.h>
+#include <linux/cleanup.h>

 struct nullb_cmd {
        blk_status_t error;
```

This might seem weird at first, but it discourages huge diffs, which are a pain
to review, and makes use of a more democratic tool which is the e-mail, that's
why maintainers like it a lot.

### What is a patch?

```
> git format-patch
GIT-FORMAT-PATCH(1) Manual GIT-FORMAT-PATCH(1)

NAME
       git-format-patch - Prepare patches for e-mail submission
```

Git format-patch command allows you to generate a diff with the commit metadata
(description and message) the Signed-off-by and Co-developed-by tags and ready
to be submitted. This is the command you need to use to generate the e-mail
body. It looks like a git diff concatenated with some information.

### What is a mailing list?

Linux is an Open Source Software, which means the revision process is also an
open process, as shown before you can access
[lore.kernel.org](https://lore.kernel.org) and see all previous e-mails,
discussions and patches. With solely e-mail this is hard, if everybody needs to
be able to participate who do you send the patch to? Linux solves this problem
with mailing lists, each Linux subsystem has its own mailing list, which anyone
can subscribe to join and add something to the discussion. The mailing lists are
available in the [lore.kernel.org](https://lore.kernel.org) home.

### How to submit your patch by git e-mail

To submit your patch you first need to configure git:

```sh
git config --global user.name "<your name>"
git config --global user.email "<your email>"
```

And then configure the smtp variables needed to actually send the e-mail:

```sh
git config --global sendemail.smtpencryption tls
git config --global sendemail.smtpserver "<your_email_smtp_server_address>"
git config --global sendemail.smtpuser "<your_email>"
git config --global sendemail.smtpserverport "<your_email_smtp_server_port>"
```

You should be able to get these by your e-mail provider, if you use Gmail you
can use:
[Send Email using git send-email via Gmail](https://www.geeksforgeeks.org/git/how-to-send-email-using-git-send-email-via-gmail/),
if you use the USP (the university I attend to) e-mail:
[Sending patches with git and USP email](https://flusp.ime.usp.br/git/sending-patches-with-git-and-a-usp-email/).
For any other provider just look into the documentation.

After this you can use `git send-email` to send your patch, for example:

```
git send-email --annotate --cover-letter --thread --no-chain-reply-to --to="test@example.com" --cc="mailing@list.com" -3
```

You of course need to check for the mailing list you need. This usually can be
found in a `MAINTAINERS` file in the root or by running the script inside
`scripts/get_maintainer.pl <file>` against the `<file>` you made changes to. If
that's not possible just look at the last commits in a file you touched and
search which mailing list it was sent to.

Some tips to use `git send-email` are:

- Always run the `scripts/checkpatch.pl` before sending your patch to make sure
  it is ready for submission.
- Use `--dry-run` to not really send the e-mail and actually just see output
- For changes made in multiple commits, you need to number them as \[PATCH 1/N\]
  and etc
- When submitting a new version you need to add a v2 like \[PATCH v2 1/N\] or v3
  and so on.
- v2/v3 patches and so on, usually include a changelog attached to it. You can
  use the `--annotate` flag for this or manually edit it after the
  `git format-patch` creation.
- If your change has multiple patches, it is common courtesy to send a 0/N cover
  letter patch explaining your changes.
- If you want to use git to answer an existing thread you need to use the flag:
  `--in-reply-to=<message-id>`. The flag `--no-chain-reply-to` makes every patch
  in the series reply to the cover letter instead of chaining patch-to-patch.

### Conclusion

Linux kernel as always has its own ways of doing things and reviewing is one of
them, but it's a refreshing experience, and nice to see a huge project which
differs from moderns standards while still keeping the bar high.

## References

\[1\]
[Sending patches by email with git](https://flusp.ime.usp.br/git/sending-patches-by-email-with-git/),
FLUSP, IME-USP

\[2\]
[Sending patches with git and USP email](https://flusp.ime.usp.br/git/sending-patches-with-git-and-a-usp-email/),
FLUSP, IME-USP

\[3\]
[Send Email using git send-email via Gmail](https://www.geeksforgeeks.org/git/how-to-send-email-using-git-send-email-via-gmail/),
GeekforGeeks
