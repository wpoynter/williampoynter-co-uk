---
title: "How can you get a computer to work out pi for you?"
date: 2022-10-14
featured: false
description: "Lots of us will have been asked to estimate pi at school using a piece of string to measure the circumference of a circle and then divide that by the diameter. But how can we estimate pi using a computer, which of course cannot handle string?"
tags: ["Data","Big Data","Communication","Scaling","NewMR"]
image: "https://newmr.org/wp-content/uploads/sites/2/2017/05/Big-Data-3-768x591.jpg"
alt: "A graphic representing big data"
link: "https://newmr.org/blog/big-data-what-is-it-and-will-it-be-here-to-stay/"
weight: 800
maths: true
sitemap:
  priority : 0.8
---

Lots of us will have been asked to estimate pi at school using a piece of string to measure the circumference of a circle and then divide that by the diameter. But how can we estimate pi using a computer, which of course cannot handle string?

In this tutorial, we may not go through the most effective way to calculate pi, but we will go through steps using knowledge we have of circles and what we know computers are good at to create a method that will work. Before we begin properly, this tutorial assumes you have a basic understanding of loops and conditions. If not, I highly recommend tools such as [Codecademy](https://www.codecademy.com/) to help you get started.

## How to calculate pi?

Some of us might remember some of the equations of circles we were taught at school. But this isn't an exam, so I will recap the common ones here:

$$
\begin{aligned} C &= 2\pi r \\\ A &= \pi r^2 \\\ r^2 &= x^2 + y^2 \\\ \text{where} \\\
A &= \text{Area} \\\ r &= \text{Radius} \\\ C &= \text{Circumference} \\\ x &= \text{X coordinate} \\\ y &= \text{Y coordinate}
\end{aligned}
$$

As mentioned before, lots of us at school will have used the first equation, a piece of string and a ruler to measure the circumference of a circle and then divide that by the diameter to get an estimate of pi (a bit over 3 in my case). But how can we do this using a computer?

Computers cannot measure the circumference of a circle very easily. But if we look at the next two equations another method of calculating pi becomes apparent. If we could work out the radius and area of a circle, we could work out pi. Better yet, if we decide the radius of the circle is 1, then the area of the circle is exactly pi. So, if we can work out the area of a circle, we can work out pi.