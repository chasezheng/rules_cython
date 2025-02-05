import unittest
from unittest import TestCase

from tests.dummy import get_refcnt
from tests.dummy_import import has_refcnt

class TestDummyFn(TestCase):
    def testGetRefCnt(self):
        obj = object()

        self.assertEqual(get_refcnt(obj), 2)
        self.assertEqual(get_refcnt(object()), 1)
        self.assertTrue(has_refcnt(obj))



if __name__ == '__main__':
    unittest.main(module=__package__)
