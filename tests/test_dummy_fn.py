import unittest
from unittest import TestCase

from tests.dummy import get_refcnt


class TestDummyFn(TestCase):
    def testGetRefCnt(self):
        obj = object()

        self.assertEqual(get_refcnt(obj), 2)
        self.assertEqual(get_refcnt(object()), 1)



if __name__ == '__main__':
    unittest.main(module=__package__)
